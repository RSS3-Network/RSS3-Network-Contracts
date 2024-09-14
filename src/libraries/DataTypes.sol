// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

using EnumerableSet for EnumerableSet.UintSet;

// solhint-disable-next-line gas-struct-packing
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
    /// @notice slashed tokens of operation pool
    uint256 slashedOperationPoolTokens;
    /// @notice slashed tokens of staking pool
    uint256 slashedStakingPoolTokens;
    /// @notice the status of the node
    NodeStatus status;
}

/// TODO: should be removed in next version
struct NodeObsoleted {
    uint256 nodeId;
    address account;
    uint64 taxRateBasisPoints;
    bool publicGood;
    bool alpha;
    string name;
    string description;
    uint256 operationPoolTokens;
    uint256 stakingPoolTokens;
    uint256 totalShares;
    bool slashStatus;
}

struct PoolStatData {
    uint256 totalOperationPoolTokens;
    uint256 totalStakingPoolTokens;
    uint256 totalSlashingPoolTokens;
}

struct Demotion {
    /// @notice unique identifier for the demotion
    uint256 demotionId;
    /// @notice address of the node being demoted
    address nodeAddr;
    /// @notice epoch when the demotion occurred
    uint256 epoch;
    /// @notice reason for the demotion
    string reason;
    /// @notice address of the account that reported the demotion
    address reporter;
}

/// @notice Enum representing the various states a node can be in
/// @param None Default state, node not yet registered
/// @param Registered Node has been registered but not yet initialized
/// @param Initializing Node is in the process of initializing
/// @param Outdated Node's software or configuration is outdated
/// @param Online Node is online and functioning normally
/// @param Offline Node is currently offline or unreachable
/// @param Slashing Node is in the process of being slashed (penalized)
/// @param Slashed Node has been slashed (penalized)
/// @param Exiting Node is in the process of exiting the network
/// @param Exited Node has successfully exited the network
enum NodeStatus {
    None, // 0
    Registered, // 1
    Initializing, // 2
    Outdated, // 3
    Online, // 4
    Offline, // 5
    Slashing, // 6
    Slashed, // 7
    Exiting, // 8
    Exited // 9

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
    /// @notice epoch number, start timestamp, end timestamp
    uint256[3] epochInfo;
    /// @notice tokens of rewards to send to staking contract for distribution
    uint256 rewardsToSend;
    /// @notice tokens of public pool rewards
    uint256 publicPoolRewards;
    /// @notice tokens of staking rewards for each node
    uint256[] stakingRewards;
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

struct NftCardTraits {
    uint8 nftCardId; // TODO: in the future
    uint256 tokenId;
    uint256 chipTokens;
    address nodeAddr;
    uint256 stakingPoolTokens;
    uint256 operationPoolTokens;
}

enum ChipVersion {
    V1,
    V2
}
