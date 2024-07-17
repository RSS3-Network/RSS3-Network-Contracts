// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,var-name-mixedcase

pragma solidity 0.8.20;
import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";
import {StorageLib} from "../storage/StorageLib.sol";
import {StakingCommonLib} from "./StakingCommonLib.sol";
import {
    NodeNotExists,
    SlashPublicGoodNode,
    SlashMoreThanOnce,
    SlashRecordNotExists,
    SlashStatusNotRecorded,
    TransferFailed
} from "./Errors.sol";

library RewardsAndSlashingLib {
    function recordSlashing(
        address nodeAddr,
        uint256 epoch,
        address reporter,
        string calldata reason,
        uint256 NODE_SLASH_RATE_BASIS_POINTS,
        uint256 USER_SLASH_RATE_BASIS_POINTS
    ) external {
        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();

        DataTypes.Node storage node = nodes[nodeAddr];

        if (nodeAddr == address(0)) revert NodeNotExists();
        if (node.publicGood) revert SlashPublicGoodNode(nodeAddr);
        if (node.slashStatus) revert SlashMoreThanOnce(nodeAddr, epoch);

        _setSlashStatus(nodeAddr, true);

        // slash operation pool tokens
        uint256 slashedOperationPool = (node.operationPoolTokens * NODE_SLASH_RATE_BASIS_POINTS) / _denominator();

        // slash staking pool tokens
        uint256 slashedStakingPool = (node.stakingPoolTokens * USER_SLASH_RATE_BASIS_POINTS) / _denominator();

        DataTypes.SlashRecord storage record = StorageLib.slashRecords()[nodeAddr][epoch];
        record.amountForOperationPool = slashedOperationPool;
        record.amountForStakingPool = slashedStakingPool;
        record.reporter = reporter;
        record.status = DataTypes.SlashStatus.Recorded;
        record.slashReason = reason;

        _recordSlashingAmount(nodeAddr, record);

        emit Events.SlashRecorded(nodeAddr, epoch, reporter, slashedOperationPool, slashedStakingPool);
    }

    function commitSlashing(
        address nodeAddr,
        uint256 epoch,
        DataTypes.SlashRecord storage record,
        uint256 SLASH_REPORTER_BONUS_RATE_BASIS_POINTS
    ) external {
        _checkRecordedStatus(record, nodeAddr, epoch);
        record.status = DataTypes.SlashStatus.Committed;
        _setSlashStatus(nodeAddr, false);
        _commitSlashingAmount(record, SLASH_REPORTER_BONUS_RATE_BASIS_POINTS);
        emit Events.SlashCommitted(nodeAddr, epoch);
    }

    function revokeSlashing(address nodeAddr, uint256 epoch, DataTypes.SlashRecord storage record) external {
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
        address[] memory nodeAddrs,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards,
        uint256 MIN_DEPOSIT,
        uint256 STAKE_RATIO
    ) external returns (uint256[] memory taxCollected) {
        taxCollected = new uint256[](nodeAddrs.length);
        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = nodes[nodeAddrs[i]];
            if (node.account == address(0) || node.publicGood || node.operationPoolTokens < MIN_DEPOSIT) {
                continue;
            }

            // operation rewards and staking rewards are sent to staking pool
            uint256 rewards = operationRewards[i] + stakingRewards[i];
            (uint256 fullTax, uint256 receivedTax) = _getTax(
                rewards,
                node.taxRateBasisPoints,
                node.operationPoolTokens,
                node.stakingPoolTokens,
                MIN_DEPOSIT,
                STAKE_RATIO
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

    /// @dev check if the status of a slash record is recorded
    function _checkRecordedStatus(DataTypes.SlashRecord memory record, address nodeAddr, uint256 epoch) internal pure {
        if (record.status == DataTypes.SlashStatus.NonExistent) revert SlashRecordNotExists(nodeAddr, epoch);
        if (record.status != DataTypes.SlashStatus.Recorded) revert SlashStatusNotRecorded(nodeAddr, epoch);
    }

    /// @dev set the status of a slash record
    function _setSlashStatus(address nodeAddr, bool status) internal {
        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();
        DataTypes.Node storage node = nodes[nodeAddr];
        node.slashStatus = status;
    }

    /// @dev
    function _recordSlashingAmount(address nodeAddr, DataTypes.SlashRecord memory record) internal {
        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();
        DataTypes.Node storage node = nodes[nodeAddr];

        StakingCommonLib.decreaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.decreaseStakingPool(node, record.amountForStakingPool);
        StakingCommonLib.increaseSlashingPoolByRecord(record);
    }

    /// @dev commit slashing amount, distributes the amount to reporter and treasury
    function _commitSlashingAmount(
        DataTypes.SlashRecord memory record,
        uint256 SLASH_REPORTER_BONUS_RATE_BASIS_POINTS
    ) internal {
        StakingCommonLib.decreaseSlashingPoolByRecord(record);

        // transfer slashed tokens to reporter
        _transfer(
            record.reporter,
            ((record.amountForOperationPool + record.amountForStakingPool) * SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) /
                _denominator()
        );
    }

    /// @dev return slashing amount
    function _revokeSlashingAmount(address nodeAddr, DataTypes.SlashRecord memory record) internal {
        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();

        DataTypes.Node storage node = nodes[nodeAddr];

        StakingCommonLib.decreaseSlashingPoolByRecord(record);
        StakingCommonLib.increaseOperationPool(node, record.amountForOperationPool);
        StakingCommonLib.increaseStakingPool(node, record.amountForStakingPool);
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
        uint256 stakingPool,
        uint256 MIN_DEPOSIT,
        uint256 STAKE_RATIO
    ) internal pure returns (uint256, uint256) {
        uint256 fullTax = _getFullTax(rewards, taxRateBasisPoints);

        if (operationPool < MIN_DEPOSIT) {
            // node will receive no tax
            return (fullTax, 0);
        } else if (operationPool >= MIN_DEPOSIT && operationPool * STAKE_RATIO >= stakingPool) {
            // node will receive its full tax
            return (fullTax, fullTax);
        } else {
            // node will receive part of its tax
            uint256 partialTax = (fullTax * operationPool * STAKE_RATIO) / stakingPool;
            return (fullTax, partialTax);
        }
    }

    /// @dev returns the full tax amount
    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints) internal pure returns (uint256) {
        return (rewards * taxRateBasisPoints) / _denominator();
    }

    /**
     * @dev denominator
     */
    function _denominator() internal pure returns (uint64) {
        return 10000;
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
}
