// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IStaking {
    /**
     * @notice Initializes the Staking contract.
     * @param pauseAccount Address who can pause/unpause the Staking contract.
     * @param oracleAccount Address who can distribute rewards to the Staking contract.
     * @param chips Chips contract.
     * @param token Staking token contract.
     * @param stakeUnbondingPeriod Time in seconds a node needs to wait to withdraw its stake
     * @param delegateUnbondingPeriod Time in seconds a user needs to wait to withdraw its stake
     */
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token,
        uint256 stakeUnbondingPeriod,
        uint256 delegateUnbondingPeriod
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
     * @param publicGood Whether the node is public good or not
     * @param taxFraction Tax percentage measured in basis points. Each basis point represents 0.01%.
     * @param rewardAddress Address which receives rewards for this operator.
     * @return nodeId The new created node id.
     */
    function createNode(
        string calldata name,
        string calldata description,
        bool publicGood,
        uint40 taxFraction,
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
    function setNodeRewardAddress(address nodeAddr, address rewardAddress) external;

    /**
     * @notice Change tax fraction of the node.
     * @param nodeAddr The address of node to change.
     * @param taxFraction The tax fraction to set.
     */
    function setNodeTax(address nodeAddr, uint40 taxFraction) external;

    /**
     * @notice Deposit tokens for node operator.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) external;

    /**
     * @notice Request unstake tokens from node operator.
     * @param amount Amount of tokens to unstake.
     * @return requestId The created unstake request id
     */
    function requestUnstake(uint256 amount) external returns (uint256 requestId);

    /**
     * @notice Withdraw operator pool rewards.
     * @param nodeAddr Address of node operator.
     */
    function withdrawOperatorPoolRewards(address nodeAddr) external;

    /**
     * @notice Claim a batch of unstake requests.
     */
    function claimUnstake(uint256[] calldata requestIds) external;

    /**
     * @notice Delegate tokens to a node operator.
     * @param nodeAddr The address of node to delegate.
     * @param amount Amount of tokens to delegate.
     * @return fromTokenId The start of new minted chips token ids.
     * @return toTokenId The end of new minted chips token ids.
     */
    function delegate(
        address nodeAddr,
        uint256 amount
    ) external returns (uint256 fromTokenId, uint256 toTokenId);

    /**
     * @notice Request undelegating tokens from a node operator.
     * @param chipsIds The chips token ids for undelegating.
     * @return requestId The created undelegate request id.
     */
    function requestUndelegate(uint256[] calldata chipsIds) external returns (uint256 requestId);

    /**
     * @notice Claim a batch of undelegate requests.
     */
    function claimUndelegate(uint256[] calldata requestIds) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     */
    function distributeRewards(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata operatorPoolRewards,
        uint256[] calldata rewardPoolRewards
    ) external;

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
