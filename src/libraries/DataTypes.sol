// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title DataTypes
 * @notice A standard library of data types.
 */
library DataTypes {
    struct Node {
        /// @notice identifier of the node
        uint256 id;
        /// @notice address of the node operator
        address account;
        /// @notice whether the node is public good or not
        bool publicGood;
        /// @notice tax percentage measured in basis points.
        uint40 taxFraction;
        /// @notice name of the node
        string name;
        /// @notice description of the node
        string description;
        /// @notice reward address of the node
        address rewardAddress;
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
        uint40 timestamp;
        /// @notice amount of tokens to undelegate
        uint256 undelegatedAmount;
        /// @notice total rewards to claim
        uint256 rewards;
    }
}
