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
     * - The caller must have the `PAUSE_ROLE`.
     */
    function pause() external;

    /**
     * @notice Resumes interaction with the Staking contract.
     * Requirements:
     * - The caller must have the `PAUSE_ROLE`.
     */
    function unpause() external;

    /**
     * @notice Creates a node named `name` with reward address `rewardAddress`.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxFraction Tax percentage measured in basis points. Each basis point represents 0.01%.
     * @param endpoint API endpoint of node.
     */
    function createNode(
        string calldata name,
        string calldata description,
        uint256 taxFraction,
        string calldata endpoint
    ) external;

    /**
     * @notice Deletes a node`.
     * @param addr The address of node.
     */
    function deleteNode(address addr) external;

    /**
     * @notice Changes tax fraction of the node.
     * @param nodeAddr The address of node to change.
     * @param taxFraction The tax fraction to set.
     * Tax percentage measured in basis points. Each basis point represents 0.01%.
     */
    function setNodeTaxFraction(address nodeAddr, uint256 taxFraction) external;

    /**
     * @notice Deposits tokens for node operator.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) external;

    /**
     * @notice Requests unstake tokens from node operator.
     * @param amount Amount of tokens to unstake.
     * @return requestId The created unstake request id
     */
    function requestUnstake(uint256 amount) external returns (uint256 requestId);

    /**
     * @notice Withdraws operator pool rewards.
     * @param nodeAddr Address of node operator.
     */
    function withdrawOperatorPoolRewards(address nodeAddr) external;

    /**
     * @notice Claims a batch of unstake requests.
     */
    function claimUnstake(uint256[] calldata requestIds) external;

    /**
     * @notice Delegates tokens to a node operator.
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
     * @notice Requests undelegating tokens from a node operator.
     * @dev This will burn the chips tokens.
     * @param nodeAddr Address of node operator to undelegate.
     * @param chipsIds The chips token ids for undelegate.
     * @return requestId THe created undelegate request id.
     */
    function requestUndelegate(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external returns (uint256 requestId);

    /**
     * @notice Claims a batch of undelegate requests.
     * @param requestIds The undelegate request ids to claim.
     */
    function claimUndelegate(uint256[] calldata requestIds) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param epoch The current epoch number.
     * @param startTimestamp The startTimestamp of the epoch.
     * @param endTimestamp The endTimestamp of the epoch.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param operatorPoolRewards Amount of rewards to operator pool.
     * @param rewardPoolRewards Amount of rewards to reward pool.
     */
    function distributeRewards(
        uint256 epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address[] calldata nodeAddrs,
        uint256[] calldata operatorPoolRewards,
        uint256[] calldata rewardPoolRewards
    ) external;

    /**
     * @notice Slashes nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs The addresses of nodes to slash.
     */
    function slashNode(address[] calldata nodeAddrs) external;

    /**
     * @notice Returns the minimal tokens to delegate for a node.
     * @param nodeAddr Address of node operator to stake.
     * @return uint256 The minimal mount of tokens to stake for a node .
     */
    function minTokensToDelegate(address nodeAddr) external view returns (uint256);

    /**
     * @notice Gets chips info by `tokenId`.
     * @param tokenId ID of Chip token.
     * @return nodeAddr Address of node operator who issues the Chip.
     * @return tokens Amount of tokens the chip is equivalent to .
     */
    function getChipsInfo(uint256 tokenId) external view returns (address nodeAddr, uint256 tokens);

    /**
     * @notice Gets node info by node address.
     * @param nodeAddr Node address to query.
     * @return DataTypes.Node Node info.
     */
    function getNode(address nodeAddr) external view returns (DataTypes.Node memory);

    /**
     * @notice Gets all nodes.
     */
    function getNodes() external view returns (DataTypes.Node[] memory);
}
