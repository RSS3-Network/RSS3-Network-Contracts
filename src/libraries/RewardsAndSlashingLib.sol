// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase
pragma solidity 0.8.24;

import {Const} from "./Const.sol";
import {Demotion, Node, NodeStatus, PoolStatData} from "./DataTypes.sol";
import {
    InvalidArrayLength,
    NodeHasNoDemotions,
    NodeIsPublicGood,
    NodeNotExists,
    SlashingNotExist
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {StakingCommonLib} from "./StakingCommonLib.sol";
import {StorageLib} from "./StorageLib.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library RewardsAndSlashingLib {
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address;

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
        // check if the lengths of the arrays are equal
        if (nodeAddrs.length != reasons.length || nodeAddrs.length != reporters.length) {
            revert InvalidArrayLength();
        }

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            _submitSingleDemotion(epoch, nodeAddrs[i], reasons[i], reporters[i]);
        }
    }

    /**
     * @dev Revoke demotions for a specific node in a given epoch.
     * @param nodeAddr The address of the node.
     * @param epoch The epoch number.
     * @param demotionIdsToRevoke An array of demotion IDs to revoke.
     */
    function revokeDemotions(
        address nodeAddr,
        uint256 epoch,
        uint256[] calldata demotionIdsToRevoke
    ) external {
        EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);
        if (demotionIds.length() == 0) revert NodeHasNoDemotions(nodeAddr, epoch);

        for (uint256 i = 0; i < demotionIdsToRevoke.length; i++) {
            demotionIds.remove(demotionIdsToRevoke[i]);
            delete StorageLib.getDemotions()[demotionIdsToRevoke[i]];

            emit Events.DemotionRevoked(demotionIdsToRevoke[i]);
        }

        Node storage node = StorageLib.getNode(nodeAddr);
        if (
            node.status == NodeStatus.Slashing
                && demotionIds.length() <= Const.DEMOTION_COUNT_THRESHOLD
        ) {
            // revoke slashing
            _revokeSlashing(node, epoch);

            // set node status: online
            node.status = NodeStatus.Online;
            emit Events.NodeStatusChanged(nodeAddr, NodeStatus.Slashing, NodeStatus.Online);
        }
    }

    /**
     * @dev Commits slashing for a specific node and epoch.
     * @param nodeAddr The address of the node being slashed.
     * @param epoch The epoch in which the slashing is being committed.
     * @param paymentProcessor The address of the payment processor.
     */
    function commitSlashing(address nodeAddr, uint256 epoch, address paymentProcessor) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.status != NodeStatus.Slashing) revert SlashingNotExist(nodeAddr, epoch);

        // set node status: slashed
        node.status = NodeStatus.Slashed;
        emit Events.NodeStatusChanged(nodeAddr, NodeStatus.Slashing, NodeStatus.Slashed);

        // commit slashing
        _commitSlashing(node, epoch, paymentProcessor);
    }

    /**
     * @notice Distributes rewards to nodes and the public pool
     * @param epochInfo An array containing epoch information [epochId, startTime, endTime]
     * @param nodeAddrs An array of node addresses to receive rewards
     * @param operationRewards An array of operation rewards corresponding to each node
     * @param stakingRewards An array of staking rewards corresponding to each node
     * @param requestCounts An array of request counts for each node
     * @param publicPoolRewards The amount of rewards for the public pool
     */
    function distributeRewards(
        uint256[3] calldata epochInfo,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata stakingRewards,
        uint256[] calldata requestCounts,
        uint256 publicPoolRewards
    ) external {
        // check if the lengths of the arrays are equal
        if (
            nodeAddrs.length != operationRewards.length || nodeAddrs.length != stakingRewards.length
                || nodeAddrs.length != requestCounts.length
        ) {
            revert InvalidArrayLength();
        }

        // distribute rewards for public pool
        if (publicPoolRewards > 0) {
            uint256 tax = _distributePublicPoolRewards(publicPoolRewards);
            emit Events.PublicGoodRewardDistributed(
                epochInfo[0], epochInfo[1], epochInfo[2], publicPoolRewards, tax
            );
        }

        // distribute rewards for non public good nodes
        uint256[] memory taxCollected =
            _distributeNodesRewards(nodeAddrs, operationRewards, stakingRewards);
        emit Events.RewardDistributed(
            epochInfo[0],
            epochInfo[1],
            epochInfo[2],
            nodeAddrs,
            operationRewards,
            stakingRewards,
            taxCollected,
            requestCounts
        );
    }

    /**
     * @notice Withdraws the remaining balance of the contract to the specified treasury address.
     * @dev The amount to be withdrawn is calculated by subtracting the total operation pool tokens,
     * total staking pool tokens, and total slashing pool tokens from the contract's balance.
     * @param treasury The address of the treasury where the funds will be transferred.
     */
    function withdraw2Treasury(address treasury) external {
        PoolStatData storage pool = StorageLib.poolStatStorage();
        uint256 amount = address(this).balance - pool.totalOperationPoolTokens
            - pool.totalStakingPoolTokens - pool.totalSlashingPoolTokens;

        _transfer(treasury, amount);
    }

    /**
     * @dev Retrieves the demotions for a specific node address and epoch.
     * @param nodeAddr The address of the node.
     * @param epoch The epoch number.
     * @return demotions An array of demotions.
     */
    function getDemotions(address nodeAddr, uint256 epoch)
        external
        view
        returns (Demotion[] memory demotions)
    {
        demotions = _getDemotions(nodeAddr, epoch);
    }

    /**
     * @dev Distributes public pool rewards to the staking pool and calculates the tax amount.
     * @param publicPoolRewards The amount of public pool rewards to be distributed.
     * @return tax The tax amount deducted from the public pool rewards.
     */
    function _distributePublicPoolRewards(uint256 publicPoolRewards)
        internal
        returns (uint256 tax)
    {
        Node storage publicPool = StorageLib.publicPool();
        // rewards for public pool
        tax = _getFullTax(publicPoolRewards, publicPool.taxRateBasisPoints);

        StakingCommonLib.increaseStakingPool(publicPool, publicPoolRewards - tax);
    }

    /**
     * @dev Distributes rewards to multiple nodes and calculates the tax collected for each.
     * @param nodeAddrs An array of node addresses to distribute rewards to.
     * @param operationRewards An array of operation rewards corresponding to each node.
     * @param stakingRewards An array of staking rewards corresponding to each node.
     * @return taxCollected An array of tax amounts collected from each node's rewards.
     */
    function _distributeNodesRewards(
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata stakingRewards
    ) internal returns (uint256[] memory taxCollected) {
        taxCollected = new uint256[](nodeAddrs.length);

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            taxCollected[i] =
                _distributeSingleNodeRewards(nodeAddrs[i], operationRewards[i], stakingRewards[i]);
        }
    }

    /**
     * @dev Distributes rewards for a single node and calculates the tax collected.
     * @param nodeAddr The address of the node receiving rewards.
     * @param operationReward The amount of operation rewards for the node.
     * @param stakingReward The amount of staking rewards for the node.
     * @return taxCollected The amount of tax collected from the node's rewards.
     */
    function _distributeSingleNodeRewards(
        address nodeAddr,
        uint256 operationReward,
        uint256 stakingReward
    ) internal returns (uint256 taxCollected) {
        Node storage node = StorageLib.getNode(nodeAddr);
        // skip non-exist node
        if (node.account == address(0) || node.publicGood) {
            return 0;
        }

        uint256 rewards = operationReward + stakingReward;
        (uint256 fullTax, uint256 receivedTax) = _getTax(
            rewards, node.taxRateBasisPoints, node.operationPoolTokens, node.stakingPoolTokens
        );

        taxCollected = receivedTax;

        // update node pool
        // taxCollected is sent to operation pool for node oeprator
        StakingCommonLib.increaseOperationPool(node, taxCollected);
        // all after-tax rewards are sent to the staking pool for stakers
        StakingCommonLib.increaseStakingPool(node, rewards - fullTax);
        // the remaining tax is sent to the treasury
    }

    /**
     * @dev Submits a single demotion for a node.
     * @param epoch The epoch for which the demotion is being submitted.
     * @param nodeAddr The address of the node being demoted.
     * @param reason The reason for the demotion.
     * @param reporter The address of the account reporting the demotion.
     */
    function _submitSingleDemotion(
        uint256 epoch,
        address nodeAddr,
        string calldata reason,
        address reporter
    ) internal {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists(nodeAddr);
        // public good node can't be demoted
        if (node.publicGood) revert NodeIsPublicGood(nodeAddr);

        uint256 demotionId = StorageLib.nextDemotionId();
        // save demotion
        StorageLib.getDemotions()[demotionId] = Demotion({
            demotionId: demotionId,
            nodeAddr: nodeAddr,
            epoch: epoch,
            reason: reason,
            reporter: reporter
        });
        // save demotion id
        EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);
        demotionIds.add(demotionId);

        // check and record slashing
        if (
            node.status != NodeStatus.Slashing
                && demotionIds.length() > Const.DEMOTION_COUNT_THRESHOLD
        ) {
            // record slashing
            _recordSlashing(node, epoch);

            // set node status: slashing
            NodeStatus curStatus = node.status;
            node.status = NodeStatus.Slashing;
            emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Slashing);
        }

        emit Events.DemotionSubmitted(epoch, nodeAddr, demotionId, reason, reporter);
    }

    /**
     * @dev  Records the slashing of a node.
     * @param node The node being slashed.
     * @param epoch The epoch for which slashing is being recorded.
     */
    function _recordSlashing(Node storage node, uint256 epoch) internal {
        // slash operation pool tokens
        uint256 slashedOperationPool =
            (node.operationPoolTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        // slash staking pool tokens
        uint256 slashedStakingPool =
            (node.stakingPoolTokens * Const.USER_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        // record slashing amount
        StakingCommonLib.decreaseOperationPool(node, slashedOperationPool);
        StakingCommonLib.decreaseStakingPool(node, slashedStakingPool);
        StakingCommonLib.increaseSlashingPool(slashedOperationPool + slashedStakingPool);
        // update slashed tokens
        node.slashedOperationPoolTokens = slashedOperationPool;
        node.slashedStakingPoolTokens = slashedStakingPool;

        emit Events.SlashRecorded(node.account, epoch, slashedOperationPool, slashedStakingPool);
    }

    /**
     * @dev Revoke slashing for a specific node and epoch.
     * @param node The node being slashed.
     * @param epoch The epoch for which slashing is being revoked.
     */
    function _revokeSlashing(Node storage node, uint256 epoch) internal {
        // revoke slashing amount
        StakingCommonLib.increaseOperationPool(node, node.slashedOperationPoolTokens);
        StakingCommonLib.increaseStakingPool(node, node.slashedStakingPoolTokens);
        StakingCommonLib.decreaseSlashingPool(
            node.slashedOperationPoolTokens + node.slashedStakingPoolTokens
        );
        // update slashed tokens
        delete node.slashedOperationPoolTokens;
        delete node.slashedStakingPoolTokens;

        emit Events.SlashRevoked(node.account, epoch);
    }

    function _commitSlashing(Node storage node, uint256 epoch, address paymentProcessor) internal {
        // commit slashing amount, distributes the amount to reporter and treasury
        uint256 slashedAmount = node.slashedOperationPoolTokens + node.slashedStakingPoolTokens;
        uint256 reporterAmount =
            (slashedAmount * Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        uint256 burnAmount =
            (slashedAmount * Const.SLASH_BURN_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        // update
        StakingCommonLib.decreaseSlashingPool(slashedAmount);
        delete node.slashedStakingPoolTokens;
        delete node.slashedOperationPoolTokens;

        // distribute slashed tokens to reporters
        _transferToReporters(reporterAmount, node.account, epoch, paymentProcessor);
        // burn slashed tokens
        _transfer(address(0x0), burnAmount);
        // remaining amount is in this contract for the treasury

        emit Events.SlashCommitted(node.account, epoch);
    }

    /**
     * @dev Transfers a specified amount of tokens to reporters based on demotions.
     *  It will divide the total amount of tokens by the number of demotions,
     * and the tokens will be transferred to the payment processor if the reporter is address(0).
     * @param amount The total amount of tokens to be transferred.
     * @param nodeAddr The address of the node to get demotions.
     * @param epoch The epoch number to get demotions.
     * @param paymentProcessor The address of the payment processor contract.
     */
    function _transferToReporters(
        uint256 amount,
        address nodeAddr,
        uint256 epoch,
        address paymentProcessor
    ) internal {
        Demotion[] memory demotions = _getDemotions(nodeAddr, epoch);
        // each reporter will receive the same amount of tokens
        uint256 averageAmount = amount / demotions.length;

        for (uint256 i = 0; i < demotions.length; i++) {
            // if reporter is address(0), transfer to payment processor
            address recipient =
                demotions[i].reporter == address(0) ? paymentProcessor : demotions[i].reporter;
            _transfer(recipient, averageAmount);
        }
    }

    /// @dev transfer native tokens by a low-level call.
    /// _transfer should always be at the end of the function,
    /// to apply the checks-effects-interactions pattern
    function _transfer(address to, uint256 amount) internal {
        Address.sendValue(payable(to), amount);
    }

    function _getDemotions(address nodeAddr, uint256 epoch)
        internal
        view
        returns (Demotion[] memory demotions)
    {
        EnumerableSet.UintSet storage demotionIds = StorageLib.getDemotionIds(nodeAddr, epoch);

        demotions = new Demotion[](demotionIds.length());
        for (uint256 i = 0; i < demotionIds.length(); i++) {
            demotions[i] = StorageLib.getDemotions()[demotionIds.at(i)];
        }
    }

    /**
     * @dev Calculate tax amount based on rewards and pool sizes.
     *  For a node operator to receive its full tax,
     * it needs to stake at least 1/25 of the tokens staked by external delegators,
     * or the exceeding part of the tax will be sent to the staking pool.
     * @param rewards Total rewards
     * @param taxRateBasisPoints Tax rate in basis points
     * @param operationPool tokens of operation pool
     * @param stakingPool tokens of staking pool
     * @return fullTax Full tax amount
     * @return receivedTax Actual tax received by node
     */
    function _getTax(
        uint256 rewards,
        uint64 taxRateBasisPoints,
        uint256 operationPool,
        uint256 stakingPool
    ) internal pure returns (uint256, uint256) {
        uint256 fullTax = _getFullTax(rewards, taxRateBasisPoints);

        // node will receive no tax if operation pool is below minimum
        if (operationPool < Const.MIN_DEPOSIT) {
            return (fullTax, 0);
        }

        // node will receive its full tax if operation pool >= 1/25 of staking pool
        if (operationPool * Const.STAKE_RATIO >= stakingPool) {
            return (fullTax, fullTax);
        }

        // node will receive part of its tax if operation pool < 1/25 of staking pool
        uint256 partialTax = (fullTax * operationPool * Const.STAKE_RATIO) / stakingPool;
        return (fullTax, partialTax);
    }

    /// @dev returns the full tax amount
    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints)
        internal
        pure
        returns (uint256)
    {
        return (rewards * taxRateBasisPoints) / Const.DENOMINATOR;
    }
}
