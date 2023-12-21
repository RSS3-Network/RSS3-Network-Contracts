// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IStaking {
    /**
     * @notice Initializes the Staking contract.
     * @param pauseAccount Address who can pause/unpause the Staking contract.
     * @param oracleAccount Address who can distribute rewards to the Staking contract.
     */
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token
    ) external;

    /**
     * @notice Pauses interaction with the Staking contract.
     * Requirements:
     * - The caller must have the PAUSE_ROLE.
     */
    function pause() external;

    /**
     * @notice Resumes interaction with the Staking contract.
     * Requirements:
     * - The caller must have the PAUSE_ROLE.
     */
    function unpause() external;

    /**
     * @notice Create a node named `name` with reward address `rewardAddress`.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param rewardAddress Address which receives rewards for this operator.
     * @return nodeId The new created node id.
     */
    function createNode(
        string calldata name,
        string calldata description,
        address rewardAddress
    ) external returns (uint256 nodeId);

    /**
     * @notice Delete a node`.
     * @param addr The address of node.
     */
    function deleteNode(address addr) external;

    /**
     * @notice Change reward address of the node.
     * @param nodeAddr The address of node to change.
     * @param rewardAddress The new rewardAddress to set.
     */
    function setNodeOperatorRewardAddress(address nodeAddr, address rewardAddress) external;

    /**
     * @notice Deposit tokens for node operator.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) external;

    /**
     * @notice Request unstake tokens from node operator.
     * @param amount Amount of tokens to unstake.
     */
    function requestUnstake(uint256 amount) external;

    /**
     * @notice Claim a batch of unstake requests.
     */
    function claimUnstake(uint256[] calldata requestIds) external;

    /**
     * @notice Delegate tokens to a node operator.
     * @param nodeAddr The address of node to delegate.
     * @param amount Amount of tokens to delegate.
     * @return uint256 The new minted chips token id and amount.
     */
    function delegate(address nodeAddr, uint256 amount) external returns (uint256, uint256);

    /**
     * @notice Request undelegate tokens from a node operator.
     * @param chipsId The token id of chips NFT.
     * @param amount Amount of chips NFT to undelegate.
     */
    function requestUndelegate(uint256 chipsId, uint256 amount) external returns (uint256);

    /**
     * @notice Claim a batch of undelegate requests.
     */
    function claimUndelegate(uint256[] calldata requestIds) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     */
    function distributeRewards() external;

    /**
     * @notice Gets node info by node id.
     * @param nodeId Node id to query.
     * @return DataTypes.Node Node info.
     */
    function getNodeById(uint256 nodeId) external view returns (DataTypes.Node memory);

    /**
     * @notice Gets node info by node address.
     * @param addr Node address to query.
     * @return DataTypes.Node Node info.
     */
    function getNodeByAddr(address addr) external view returns (DataTypes.Node memory);

    /**
     * @notice Gets all nodes info.
     */
    function getNodes() external view returns (DataTypes.Node[] memory);
}
