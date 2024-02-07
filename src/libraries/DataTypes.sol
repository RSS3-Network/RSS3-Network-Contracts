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
        /// @notice tax rate measured in basis points.
        uint64 taxRateBasisPoints;
        /// @notice flag indicating if the node is a public good
        bool publicGood;
        /// @notice name of the node
        string name;
        /// @notice description of the node
        string description;
        /// @notice total tokens of operation pool
        uint256 operationPoolTokens;
        /// @notice total tokens of staking pool
        uint256 stakingPoolTokens;
        /// @notice total shares of the pool
        uint256 totalShares;
        /// @notice total amount of slashed tokens
        uint256 slashedTokens;
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

    struct NodeTraits {
        uint8 frameColor;
        uint8 frameId;
        uint8 chipDetailColor;
        uint8 chipDetailId;
        // uint8 chipCornerId; // TODO: in the future
        bool pgCorner; // true: public good node corner; false: alpha node corner
    }

    struct ChipTraits {
        uint8 eyesId;
        uint8 mouthId;
        uint8 headShapeColor;
        uint8 headShapeId;
        uint8 headDetailColor;
        uint8 headDetailId;
    }
}
