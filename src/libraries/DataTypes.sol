// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title DataTypes
 * @notice A standard library of data types.
 */
library DataTypes {
    struct Node {
        /// @notice address of the node operator
        address account;
        /// @notice tax percentage measured in basis points.
        uint256 taxFraction;
        /// @notice name of the node
        string name;
        /// @notice description of the node
        string description;
        /// @notice API endpoint of the node
        string endpoint;
        /// @notice amount of tokens staked by node itself
        uint256 selfStakedAmount;
        /// @notice amount of tokens delegated by users
        uint256 delegatedAmount;
        /// @notice total rewards of operator pool
        uint256 operatorPoolTotalRewards;
        /// @notice claimed rewards of operator pool
        uint256 claimedOperatorPoollRewards;
        /// @notice total rewards of reward pool
        uint256 rewardPoolTotalRewards;
        /// @notice total shares of the pool
        uint256 totalShares;
        /// @notice total amount of slashed tokens
        uint256 slashedAmount;
    }

    struct UnstakeRequest {
        /// @notice address that can claim request
        address owner;
        /// @notice flag indicating if the request was claimed
        bool claimed;
        /// @notice block.timestamp when the request was created
        uint40 timestamp;
        /// @notice amount of tokens to unstake
        uint256 unstakedAmount;
    }

    struct UndelegateRequest {
        /// @notice address that can claim request
        address owner;
        /// @notice flag indicating if the request was claimed
        bool claimed;
        /// @notice block.timestamp when the request was created
        uint256 timestamp;
        /// @notice amount of tokens to undelegate
        uint256 undelegatedAmount;
        /// @notice total rewards to claim
        uint256 rewards;
    }
}
