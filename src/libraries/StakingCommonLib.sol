// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore

pragma solidity 0.8.20;

import {Node, PoolStatData} from "./DataTypes.sol";
import {StorageLib} from "./StorageLib.sol";

library StakingCommonLib {
    /// @dev increase staking pool tokens of a node, and total staking pool tokens
    function increaseStakingPool(Node storage node, uint256 amount) internal {
        node.stakingPoolTokens += amount;

        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalStakingPoolTokens += amount;
    }

    /// @dev decrease staking pool tokens of a node, and total staking pool tokens
    function decreaseStakingPool(Node storage node, uint256 amount) internal {
        node.stakingPoolTokens -= amount;

        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalStakingPoolTokens -= amount;
    }

    /// @dev increase operation pool tokens of a node, and total operation pool tokens
    function increaseOperationPool(Node storage node, uint256 amount) internal {
        node.operationPoolTokens += amount;

        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalOperationPoolTokens += amount;
    }

    /// @dev decrease operation pool tokens of a node, and total operation pool tokens
    function decreaseOperationPool(Node storage node, uint256 amount) internal {
        node.operationPoolTokens -= amount;

        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalOperationPoolTokens -= amount;
    }

    /// @dev increase slashing pool tokens
    function increaseSlashingPool(uint256 amount) internal {
        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalSlashingPoolTokens += amount;
    }

    /// @dev decrease slashing pool tokens
    function decreaseSlashingPool(uint256 amount) internal {
        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalSlashingPoolTokens -= amount;
    }
}
