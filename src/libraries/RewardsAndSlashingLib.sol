// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase
pragma solidity 0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Const} from "./Const.sol";
import {Node, Demotion, NodeStatus, PoolStatData, SlashStatus, SlashRecord} from "./DataTypes.sol";
import {
    NodeNotExists,
    SlashMoreThanOnce,
    SlashRecordNotExists,
    SlashStatusNotRecorded,
    TransferFailed,
    InvalidArrayLength
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {StakingCommonLib} from "./StakingCommonLib.sol";
import {StorageLib} from "./StorageLib.sol";

library RewardsAndSlashingLib {
    using EnumerableSet for EnumerableSet.UintSet;

    /**
     * @dev Submits demotions for a given epoch and node addresses.
     * @param epoch The epoch for which demotions are being submitted.
     * @param nodeAddrs An array of node addresses to be demoted.
     * @param reasons An array of reasons for the demotions.
     * @param reporters An array of addresses of the reporters of the demotions.
     */
    function submitDemotions(
        uint256 epoch,
        address[] calldata nodeAddrs,
        string[] calldata reasons,
        address[] calldata reporters
    ) external {
        if (nodeAddrs.length != reasons.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];

            SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
            EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);

            uint256 demotionId = StorageLib.nextDemotionId();
            // save demotion id
            demotionIds.add(demotionId);
            // save demotion
            StorageLib.getDemotions()[demotionId] = Demotion({
                demotionId: demotionId,
                nodeAddr: nodeAddr,
                epoch: epoch,
                reason: reasons[i],
                reporter: reporters[i]
            });

            if (record.status != SlashStatus.Recorded && demotionIds.length() > Const.DEMOTION_COUNT_THRESHOLD) {
                // slash
                _recordSlashing(nodeAddr, epoch, address(0));
            }

            emit Events.DemotionSubmitted(epoch, nodeAddr, demotionId, reasons[i], reporters[i]);
        }
    }

    /**
     * @dev Revoke demotions for a specific node in a given epoch.
     * @param nodeAddr The address of the node.
     * @param epoch The epoch number.
     * @param demotionIdsToDelete An array of demotion IDs to delete.
     */
    function revokeDemotions(address nodeAddr, uint256 epoch, uint256[] calldata demotionIdsToDelete) external {
        EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);

        for (uint256 i = 0; i < demotionIdsToDelete.length; i++) {
            demotionIds.remove(demotionIdsToDelete[i]);
            delete StorageLib.getDemotions()[demotionIdsToDelete[i]];

            emit Events.DemotionRevoked(demotionIdsToDelete[i]);
        }

        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        if (record.status == SlashStatus.Recorded && demotionIds.length() <= Const.DEMOTION_COUNT_THRESHOLD) {
            // slash
            _revokeSlashing(nodeAddr, epoch);
        }
    }

    /**
     * @dev Commits slashing for a specific node and epoch.
     * @param nodeAddr The address of the node being slashed.
     * @param epoch The epoch in which the slashing is being committed.
     * @param paymentProcessor The address of the payment processor.
     */
    function commitSlashing(address nodeAddr, uint256 epoch, address paymentProcessor) external {
        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        _checkRecordedStatus(record, nodeAddr, epoch);
        record.status = SlashStatus.Committed;

        // set node status: slashed
        Node storage node = StorageLib.getNode(nodeAddr);
        node.status = NodeStatus.Slashed;

        // commit slashing amount, distributes the amount to reporter and treasury
        uint256 slashedAmount = record.amountForOperationPool + record.amountForStakingPool;
        uint256 reporterAmount = (slashedAmount * Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        uint256 burnAmount = (slashedAmount * Const.SLASH_BURN_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        StakingCommonLib.decreaseSlashingPoolByRecord(slashedAmount);

        // transfer slashed tokens to reporters
        _transferToReporters(reporterAmount, nodeAddr, epoch, paymentProcessor);
        // burn slashed tokens
        _transfer(address(0x0), burnAmount);
        // remaining amount is in this contract for the treasury

        emit Events.SlashCommitted(nodeAddr, epoch);
    }

    /**
     * @dev Distributes public pool rewards to the staking pool and calculates the tax amount.
     * @param publicPoolRewards The amount of public pool rewards to be distributed.
     * @return The tax amount deducted from the public pool rewards.
     */
    function distributePublicPoolRewards(uint256 publicPoolRewards) external returns (uint256) {
        Node storage publicPool = StorageLib.publicPool();
        // rewards for public pool
        uint256 tax = _getFullTax(publicPoolRewards, publicPool.taxRateBasisPoints);

        StakingCommonLib.increaseStakingPool(publicPool, publicPoolRewards - tax);

        return tax;
    }

    function distributeNodesRewards(
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata stakingRewards
    ) external returns (uint256[] memory taxCollected) {
        taxCollected = new uint256[](nodeAddrs.length);

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            Node storage node = StorageLib.getNode(nodeAddrs[i]);
            if (node.account == address(0) || node.publicGood || node.operationPoolTokens < Const.MIN_DEPOSIT) {
                continue;
            }

            // operation rewards and staking rewards are sent to staking pool
            uint256 rewards = operationRewards[i] + stakingRewards[i];
            (uint256 fullTax, uint256 receivedTax) = _getTax(
                rewards,
                node.taxRateBasisPoints,
                node.operationPoolTokens,
                node.stakingPoolTokens
            );

            taxCollected[i] = receivedTax;

            // update node pool
            // receivedTax is sent to operation pool
            StakingCommonLib.increaseOperationPool(node, receivedTax);
            // all after-tax rewards are sent to the staking pool
            StakingCommonLib.increaseStakingPool(node, rewards - fullTax);
            // the remaining tax is sent to the treasury
        }
    }

    /**
     * @notice Withdraws the remaining balance of the contract to the specified treasury address.
     * @dev The amount to be withdrawn is calculated by subtracting the total operation pool tokens,
     * total staking pool tokens, and total slashing pool tokens from the contract's balance.
     * @param treasury The address of the treasury where the funds will be transferred.
     */
    function withdraw2Treasury(address treasury) external {
        PoolStatData storage pool = StorageLib.poolStatStorage();
        uint256 amount = address(this).balance -
            pool.totalOperationPoolTokens -
            pool.totalStakingPoolTokens -
            pool.totalSlashingPoolTokens;

        _transfer(treasury, amount);
    }

    /**
     * @dev Retrieves the demotions for a specific node address and epoch.
     * @param nodeAddr The address of the node.
     * @param epoch The epoch number.
     * @return demotions An array of demotions.
     */
    function getDemotions(address nodeAddr, uint256 epoch) external view returns (Demotion[] memory demotions) {
        demotions = _getDemotions(nodeAddr, epoch);
    }

    /**
     * @dev Records the slashing of a node.
     * @param nodeAddr The address of the node being slashed.
     * @param epoch The epoch in which the slashing occurred.
     * @param reporter The address of the reporter who initiated the slashing.
     */
    function _recordSlashing(address nodeAddr, uint256 epoch, address reporter) internal {
        Node storage node = StorageLib.getNode(nodeAddr);

        if (nodeAddr == address(0)) revert NodeNotExists();
        // A public good node can't be slashed.
        if (node.publicGood) return;
        if (node.status == NodeStatus.Slashing) revert SlashMoreThanOnce(nodeAddr, epoch);

        // slash operation pool tokens
        uint256 slashedOperationPool = (node.operationPoolTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            Const.DENOMINATOR;

        // slash staking pool tokens
        uint256 slashedStakingPool = (node.stakingPoolTokens * Const.USER_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        // update slash record
        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        record.amountForOperationPool = slashedOperationPool;
        record.amountForStakingPool = slashedStakingPool;
        record.status = SlashStatus.Recorded;

        // record slashing amount
        StakingCommonLib.decreaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.decreaseStakingPool(node, record.amountForStakingPool);
        StakingCommonLib.increaseSlashingPoolByRecord(record.amountForOperationPool + record.amountForStakingPool);

        NodeStatus curStatus = node.status;
        // set node status: slashing
        node.status = NodeStatus.Slashing;
        emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Slashing);

        emit Events.SlashRecorded(nodeAddr, epoch, reporter, slashedOperationPool, slashedStakingPool);
    }

    /**
     * @dev Revoke slashing for a specific node and epoch.
     * @param nodeAddr The address of the node.
     * @param epoch The epoch for which slashing is being revoked.
     */
    function _revokeSlashing(address nodeAddr, uint256 epoch) internal {
        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        Node storage node = StorageLib.getNode(nodeAddr);

        _checkRecordedStatus(record, nodeAddr, epoch);
        record.status = SlashStatus.Revoked;

        // revoke slashing amount
        StakingCommonLib.decreaseSlashingPoolByRecord(record.amountForOperationPool + record.amountForStakingPool);
        StakingCommonLib.increaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.increaseStakingPool(node, record.amountForStakingPool);
        // set node status: online
        node.status = NodeStatus.Online;
        emit Events.NodeStatusChanged(nodeAddr, NodeStatus.Slashing, NodeStatus.Online);

        emit Events.SlashRevoked(nodeAddr, epoch);
    }

    function _transferToReporters(uint256 amount, address nodeAddr, uint256 epoch, address paymentProcessor) internal {
        Demotion[] memory demotions = _getDemotions(nodeAddr, epoch);
        uint256 averageAmount = amount / demotions.length;

        for (uint256 i = 0; i < demotions.length; i++) {
            address reporter = demotions[i].reporter;
            if (reporter == address(0)) {
                // transfer slashed tokens to payment processor
                _transfer(paymentProcessor, averageAmount);
            } else {
                // transfer slashed tokens to reporter
                _transfer(reporter, averageAmount);
            }
        }
    }

    /// @dev transfer native tokens by a low-level call.
    /// _transfer should always be at the end of the function,
    /// to apply the checks-effects-interactions pattern
    function _transfer(address to, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = address(to).call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }

    function _getDemotions(address nodeAddr, uint256 epoch) internal view returns (Demotion[] memory demotions) {
        EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);

        demotions = new Demotion[](demotionIds.length());
        for (uint256 i = 0; i < demotionIds.length(); i++) {
            demotions[i] = StorageLib.getDemotions()[demotionIds.at(i)];
        }
    }

    /// @dev check if the status of a slash record is recorded
    function _checkRecordedStatus(SlashRecord memory record, address nodeAddr, uint256 epoch) internal pure {
        if (record.status == SlashStatus.NonExistent) revert SlashRecordNotExists(nodeAddr, epoch);
        if (record.status != SlashStatus.Recorded) revert SlashStatusNotRecorded(nodeAddr, epoch);
    }

    /**
     * @dev get tax amount
     *  For a node operator to receive its full tax,
     * it needs to stake at least 1/25 of the tokens staked by external delegators,
     * or the exceeding part of the tax will be sent to the staking pool.
     */
    function _getTax(
        uint256 rewards,
        uint64 taxRateBasisPoints,
        uint256 operationPool,
        uint256 stakingPool
    ) internal pure returns (uint256, uint256) {
        uint256 fullTax = _getFullTax(rewards, taxRateBasisPoints);

        if (operationPool < Const.MIN_DEPOSIT) {
            // node will receive no tax
            return (fullTax, 0);
        } else if (operationPool >= Const.MIN_DEPOSIT && operationPool * Const.STAKE_RATIO >= stakingPool) {
            // node will receive its full tax
            return (fullTax, fullTax);
        } else {
            // node will receive part of its tax
            uint256 partialTax = (fullTax * operationPool * Const.STAKE_RATIO) / stakingPool;
            return (fullTax, partialTax);
        }
    }

    /// @dev returns the full tax amount
    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints) internal pure returns (uint256) {
        return (rewards * taxRateBasisPoints) / Const.DENOMINATOR;
    }
}
