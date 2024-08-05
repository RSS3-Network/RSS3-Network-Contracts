// SPDX-License-Identifier: MIT
// solhint-disable var-name-mixedcase
pragma solidity 0.8.20;

import {Const} from "./Const.sol";
import {DataTypes} from "./DataTypes.sol";
import {
    NodeNotExists,
    SlashMoreThanOnce,
    SlashRecordNotExists,
    SlashStatusNotRecorded,
    TransferFailed
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {StakingCommonLib} from "./StakingCommonLib.sol";
import {StorageLib} from "./StorageLib.sol";

library RewardsAndSlashingLib {
    function recordSlashing(address nodeAddr, uint256 epoch, address reporter, string calldata reason) external {
        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

        if (nodeAddr == address(0)) revert NodeNotExists();
        // A public good node can't be slashed.
        if (node.publicGood) return;
        if (node.slashStatus) revert SlashMoreThanOnce(nodeAddr, epoch);

        _setSlashStatus(nodeAddr, true);

        // slash operation pool tokens
        uint256 slashedOperationPool = (node.operationPoolTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            Const.DENOMINATOR;

        // slash staking pool tokens
        uint256 slashedStakingPool = (node.stakingPoolTokens * Const.USER_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        DataTypes.SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);

        record.amountForOperationPool = slashedOperationPool;
        record.amountForStakingPool = slashedStakingPool;
        record.reporter = reporter;
        record.status = DataTypes.SlashStatus.Recorded;
        record.slashReason = reason;

        _recordSlashingAmount(nodeAddr, record);

        // set node status
        StorageLib.setNodeStatus(nodeAddr, DataTypes.NodeStatus.Slashed);

        emit Events.SlashRecorded(nodeAddr, epoch, reporter, slashedOperationPool, slashedStakingPool);
    }

    function commitSlashing(address nodeAddr, uint256 epoch, address paymentProcessor) external {
        DataTypes.SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);
        _checkRecordedStatus(record, nodeAddr, epoch);
        record.status = DataTypes.SlashStatus.Committed;
        _setSlashStatus(nodeAddr, false);

        _commitSlashingAmount(record, paymentProcessor);
        emit Events.SlashCommitted(nodeAddr, epoch);
    }

    function revokeSlashing(address nodeAddr, uint256 epoch) external {
        DataTypes.SlashRecord storage record = StorageLib.getSlashRecord(nodeAddr, epoch);

        _checkRecordedStatus(record, nodeAddr, epoch);

        record.status = DataTypes.SlashStatus.Revoked;

        _setSlashStatus(nodeAddr, false);

        _revokeSlashingAmount(nodeAddr, record);
        emit Events.SlashRevoked(nodeAddr, epoch);
    }

    function distributePublicPoolRewards(uint256 publicPoolRewards) external returns (uint256) {
        DataTypes.Node storage publicPool = StorageLib.publicPool();
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
            DataTypes.Node storage node = StorageLib.getNode(nodeAddrs[i]);
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
    /// @dev set the status of a slash record
    function _setSlashStatus(address nodeAddr, bool status) internal {
        StorageLib.getNode(nodeAddr).slashStatus = status;
    }

    /// @dev
    function _recordSlashingAmount(address nodeAddr, DataTypes.SlashRecord storage record) internal {
        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

        StakingCommonLib.decreaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.decreaseStakingPool(node, record.amountForStakingPool);
        StakingCommonLib.increaseSlashingPoolByRecord(record);
    }

    /// @dev commit slashing amount, distributes the amount to reporter and treasury
    function _commitSlashingAmount(DataTypes.SlashRecord storage record, address paymentProcessor) internal {
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

    /// @dev return slashing amount
    function _revokeSlashingAmount(address nodeAddr, DataTypes.SlashRecord storage record) internal {
        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

        StakingCommonLib.decreaseSlashingPoolByRecord(record);
        StakingCommonLib.increaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.increaseStakingPool(node, record.amountForStakingPool);
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
    function _checkRecordedStatus(DataTypes.SlashRecord memory record, address nodeAddr, uint256 epoch) internal pure {
        if (record.status == DataTypes.SlashStatus.NonExistent) revert SlashRecordNotExists(nodeAddr, epoch);
        if (record.status != DataTypes.SlashStatus.Recorded) revert SlashStatusNotRecorded(nodeAddr, epoch);
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
