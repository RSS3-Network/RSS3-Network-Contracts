// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore

pragma solidity 0.8.20;
import {DataTypes} from "./DataTypes.sol";
import {StorageLib} from "./StorageLib.sol";

library StakingCommonLib {
    /// @dev increase staking pool tokens of a node, and total staking pool tokens
    function increaseStakingPool(DataTypes.Node storage node, uint256 amount) external {
        node.stakingPoolTokens += amount;
        uint256 newTotalStakingPoolTokens = StorageLib.getTotalStakingPoolTokens() + amount;
        StorageLib.setTotalStakingPoolTokens(newTotalStakingPoolTokens);
    }

    /// @dev decrease staking pool tokens of a node, and total staking pool tokens
    function decreaseStakingPool(DataTypes.Node storage node, uint256 amount) external {
        node.stakingPoolTokens -= amount;
        uint256 newTotalStakingPoolTokens = StorageLib.getTotalStakingPoolTokens() - amount;
        StorageLib.setTotalStakingPoolTokens(newTotalStakingPoolTokens);
    }

    /// @dev increase operation pool tokens of a node, and total operation pool tokens
    function increaseOperationPool(DataTypes.Node storage node, uint256 amount) external {
        node.operationPoolTokens += amount;
        uint256 newOperationPoolTokens = StorageLib.getTotalOperatingPoolTokens() + amount;
        StorageLib.setTotalOperationPoolTokens(newOperationPoolTokens);
    }

    /// @dev decrease operation pool tokens of a node, and total operation pool tokens
    function decreaseOperationPool(DataTypes.Node storage node, uint256 amount) external {
        node.operationPoolTokens -= amount;
        uint256 newTotalOperationPoolTokens = StorageLib.getTotalOperatingPoolTokens() - amount;
        StorageLib.setTotalOperationPoolTokens(newTotalOperationPoolTokens);
    }

    /// @dev increase slashing pool tokens
    function increaseSlashingPoolByRecord(DataTypes.SlashRecord calldata record) external {
        uint256 newSlashingPoolTokens = StorageLib.getTotalSlashingPoolTokens() + _totalSlashedAmount(record);
        StorageLib.setTotalSlashingPoolTokens(newSlashingPoolTokens);
    }

    /// @dev decrease slashing pool tokens
    function decreaseSlashingPoolByRecord(DataTypes.SlashRecord calldata record) external {
        uint256 newSlashingPoolTokens = StorageLib.getTotalSlashingPoolTokens() - _totalSlashedAmount(record);
        StorageLib.setTotalSlashingPoolTokens(newSlashingPoolTokens);
    }

    function _totalSlashedAmount(DataTypes.SlashRecord calldata record) internal pure returns (uint256) {
        return record.amountForOperationPool + record.amountForStakingPool;
    }
}
