// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase
pragma solidity 0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Const} from "./Const.sol";
import {Node, NodeStatus, SlashStatus, SlashRecord} from "./DataTypes.sol";
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

    function submitDemotions(uint256 epoch, address[] calldata nodeAddrs, string[] calldata reasons) external {
        if (nodeAddrs.length != reasons.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];

            SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
            EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);

            uint256 demotionId = StorageLib.nextDemotionId();
            demotionIds.add(demotionId);
            StorageLib.getDemotionReasons()[demotionId] = reasons[i];

            if (record.status != SlashStatus.Recorded && demotionIds.length() > Const.DEMOTION_COUNT_THRESHOLD) {
                // slash
                _recordSlashing(nodeAddr, epoch, address(0));
            }

            emit Events.DemotionSubmitted(epoch, nodeAddr, demotionId, reasons[i]);
        }
    }

    function revokeDemotions(address nodeAddr, uint256 epoch, uint256[] calldata demotionIdsToDelete) external {
        EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);

        for (uint256 i = 0; i < demotionIdsToDelete.length; i++) {
            demotionIds.remove(demotionIdsToDelete[i]);
            delete StorageLib.getDemotionReasons()[demotionIdsToDelete[i]];

            emit Events.DemotionRevoked(demotionIdsToDelete[i]);
        }

        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        if (record.status == SlashStatus.Recorded && demotionIds.length() <= Const.DEMOTION_COUNT_THRESHOLD) {
            // slash
            _revokeSlashing(nodeAddr, epoch);
        }
    }

    function commitSlashing(address nodeAddr, uint256 epoch, address paymentProcessor) external {
        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        _checkRecordedStatus(record, nodeAddr, epoch);
        record.status = SlashStatus.Committed;

        // set node status: slashed
        Node storage node = StorageLib.getNode(nodeAddr);
        node.status = NodeStatus.Slashed;

        _commitSlashingAmount(record, paymentProcessor);
        emit Events.SlashCommitted(nodeAddr, epoch);
    }

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

    function withdraw2Treasury(address treasury, uint256 amount) external {
        _transfer(treasury, amount);
    }

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
        record.reporter = reporter;
        record.amountForOperationPool = slashedOperationPool;
        record.amountForStakingPool = slashedStakingPool;
        record.status = SlashStatus.Recorded;

        // record slashing amount
        StakingCommonLib.decreaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.decreaseStakingPool(node, record.amountForStakingPool);
        StakingCommonLib.increaseSlashingPoolByRecord(record);

        NodeStatus curStatus = node.status;
        // set node status: slashing
        node.status = NodeStatus.Slashing;
        emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Slashing);

        emit Events.SlashRecorded(nodeAddr, epoch, reporter, slashedOperationPool, slashedStakingPool);
    }

    function _revokeSlashing(address nodeAddr, uint256 epoch) internal {
        SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        Node storage node = StorageLib.getNode(nodeAddr);

        _checkRecordedStatus(record, nodeAddr, epoch);
        record.status = SlashStatus.Revoked;

        // revoke slashing amount
        StakingCommonLib.decreaseSlashingPoolByRecord(record);
        StakingCommonLib.increaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.increaseStakingPool(node, record.amountForStakingPool);
        // set node status: online
        node.status = NodeStatus.Online;
        emit Events.NodeStatusChanged(nodeAddr, NodeStatus.Slashing, NodeStatus.Online);

        emit Events.SlashRevoked(nodeAddr, epoch);
    }

    /// @dev commit slashing amount, distributes the amount to reporter and treasury
    function _commitSlashingAmount(SlashRecord storage record, address paymentProcessor) internal {
        StakingCommonLib.decreaseSlashingPoolByRecord(record);

        uint256 amount = record.amountForOperationPool + record.amountForStakingPool;

        uint256 reporterAmount = (amount * Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        uint256 burnAmount = (amount * Const.SLASH_BURN_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        if (record.reporter == address(0)) {
            // transfer slashed tokens to payment processor
            _transfer(paymentProcessor, reporterAmount);
        } else {
            // transfer slashed tokens to reporter
            _transfer(record.reporter, reporterAmount);
        }
        _transfer(address(0x0), burnAmount);

        // remaining amount is in this contract for the treasury
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
