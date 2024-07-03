// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title DataTypes
 * @notice A standard library of data types.
 */
library DataTypes {
    struct Node {
        /// @notice unique identifier of the node
        uint256 nodeId;
        /// @notice address of the node operator
        address account;
        /// @notice tax rate measured in basis points.
        uint64 taxRateBasisPoints;
        /// @notice flag indicating if the node is a public good
        bool publicGood;
        /// @notice flag indicating if the node is created in alpha phase
        bool alpha;
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
        uint256 reservedData;
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
        /// @notice address of the node operator
        address nodeAddr;
        /// @notice block.timestamp when the request was created
        uint256 timestamp;
        /// @notice amount of tokens to unstake
        uint256 unstakeAmount;
    }

    struct RewardsData {
        uint256[3] epochInfo;
        uint256 rewardsToSend;
        uint256 publicPoolRewards;
        uint256[] stakingRewards;
    }

    enum SlashStatus {
        Recorded,
        Committed,
        Revoked
    }

    struct SlashRecord {
        address nodeAddr;
        address reporter;
        uint256 epoch;
        uint256 amountForOperationPool;
        uint256 amountForStakingPool;
        SlashStatus status; // 0: recorded, 1: committed, 2: revoked
        bytes reservedData;
    }

    struct NodeTraits {
        uint8 frameColor;
        uint8 frameId;
        uint8 chipDetailColor;
        uint8 chipDetailId;
        uint8 chipCornerId; // TODO: in the future
        bool pg; // true: is public good node
        bool alpha; // true: is alpha node
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
