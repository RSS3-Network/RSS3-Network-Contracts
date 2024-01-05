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
        uint64 taxFraction;
        /// @notice flag indicating if the node is a public good
        bool publicGood;
        /// @notice name of the node
        string name;
        /// @notice description of the node
        string description;
        /// @notice API endpoint of the node
        string endpoint;
        /// @notice total tokens of operator pool
        uint256 operatingPool;
        /// @notice total tokens of reward pool
        uint256 stakingPool;
        /// @notice total shares of the pool
        uint256 totalShares;
        /// @notice total amount of slashed tokens
        uint256 slashedAmount;
    }

    struct WithdrawalRequest {
        /// @notice address that can claim request
        address owner;
        /// @notice block.timestamp when the request was created
        uint40 timestamp;
        /// @notice amount of tokens to withdraw
        uint256 amount;
    }

    struct UnstakeRequest {
        /// @notice address that can claim request
        address owner;
        /// @notice Address of the node operator
        address nodeAddr;
        /// @notice block.timestamp when the request was created
        uint256 timestamp;
        /// @notice amount of tokens to unstake
        uint256 unstakeAmount;
    }
}
