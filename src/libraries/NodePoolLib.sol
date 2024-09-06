// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore

pragma solidity 0.8.24;

import {Node} from "./DataTypes.sol";
import {StorageLib} from "./StorageLib.sol";

library NodePoolLib {
    /// @dev increase staking pool tokens of a node, and total staking pool tokens
    function increaseStakingPool(Node storage node, uint256 amount) internal {
        node.stakingPoolTokens += amount;
        StorageLib.poolStatStorage().totalStakingPoolTokens += amount;
    }

    /// @dev decrease staking pool tokens of a node, and total staking pool tokens
    function decreaseStakingPool(Node storage node, uint256 amount) internal {
        node.stakingPoolTokens -= amount;
        StorageLib.poolStatStorage().totalStakingPoolTokens -= amount;
    }

    /// @dev increase operation pool tokens of a node, and total operation pool tokens
    function increaseOperationPool(Node storage node, uint256 amount) internal {
        node.operationPoolTokens += amount;
        StorageLib.poolStatStorage().totalOperationPoolTokens += amount;
    }

    /// @dev decrease operation pool tokens of a node, and total operation pool tokens
    function decreaseOperationPool(Node storage node, uint256 amount) internal {
        node.operationPoolTokens -= amount;
        StorageLib.poolStatStorage().totalOperationPoolTokens -= amount;
    }

    /// @dev increase slashing pool tokens
    function increaseSlashingPool(
        Node storage node,
        uint256 slashedOperationPool,
        uint256 slashedStakingPool
    ) internal {
        node.slashedOperationPoolTokens = slashedOperationPool;
        node.slashedStakingPoolTokens = slashedStakingPool;
        StorageLib.poolStatStorage().totalSlashingPoolTokens +=
            (slashedOperationPool + slashedStakingPool);
    }

    /// @dev decrease slashing pool tokens
    function decreaseSlashingPool(
        Node storage node,
        uint256 slashedOperationPool,
        uint256 slashedStakingPool
    ) internal {
        delete node.slashedOperationPoolTokens;
        delete node.slashedStakingPoolTokens;
        StorageLib.poolStatStorage().totalSlashingPoolTokens -=
            (slashedOperationPool + slashedStakingPool);
    }
}
