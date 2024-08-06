// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore

pragma solidity 0.8.20;

import {Node, SlashRecord} from "./DataTypes.sol";
import {StorageLib} from "./StorageLib.sol";

library StakingCommonLib {
    /// @dev increase staking pool tokens of a node, and total staking pool tokens
    function increaseStakingPool(Node storage node, uint256 amount) internal {
        node.stakingPoolTokens += amount;
        uint256 newTotalStakingPoolTokens = StorageLib.getTotalStakingPoolTokens() + amount;
        StorageLib.setTotalStakingPoolTokens(newTotalStakingPoolTokens);
    }

    /// @dev decrease staking pool tokens of a node, and total staking pool tokens
    function decreaseStakingPool(Node storage node, uint256 amount) internal {
        node.stakingPoolTokens -= amount;
        uint256 newTotalStakingPoolTokens = StorageLib.getTotalStakingPoolTokens() - amount;
        StorageLib.setTotalStakingPoolTokens(newTotalStakingPoolTokens);
    }

    /// @dev increase operation pool tokens of a node, and total operation pool tokens
    function increaseOperationPool(Node storage node, uint256 amount) internal {
        node.operationPoolTokens += amount;
        uint256 newOperationPoolTokens = StorageLib.getTotalOperatingPoolTokens() + amount;
        StorageLib.setTotalOperationPoolTokens(newOperationPoolTokens);
    }

    /// @dev decrease operation pool tokens of a node, and total operation pool tokens
    function decreaseOperationPool(Node storage node, uint256 amount) internal {
        node.operationPoolTokens -= amount;
        uint256 newTotalOperationPoolTokens = StorageLib.getTotalOperatingPoolTokens() - amount;
        StorageLib.setTotalOperationPoolTokens(newTotalOperationPoolTokens);
    }

    /// @dev increase slashing pool tokens
    function increaseSlashingPoolByRecord(SlashRecord storage record) internal {
        uint256 newSlashingPoolTokens = StorageLib.getTotalSlashingPoolTokens() + _totalSlashedAmount(record);
        StorageLib.setTotalSlashingPoolTokens(newSlashingPoolTokens);
    }

    /// @dev decrease slashing pool tokens
    function decreaseSlashingPoolByRecord(SlashRecord storage record) internal {
        uint256 newSlashingPoolTokens = StorageLib.getTotalSlashingPoolTokens() - _totalSlashedAmount(record);
        StorageLib.setTotalSlashingPoolTokens(newSlashingPoolTokens);
    }

    function _totalSlashedAmount(SlashRecord storage record) internal view returns (uint256) {
        return record.amountForOperationPool + record.amountForStakingPool;
    }
}
