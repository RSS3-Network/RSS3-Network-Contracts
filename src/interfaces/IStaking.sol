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
     * @param stakeUnbondingPeriod Time in seconds user need to wait to unstake its stake.
     * @param depositUnbondingPeriod Time in seconds node operator need to wait to withdraw its deposit.
     */
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod
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
     * @notice Creates a node.
     * @param to Address of node operator.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxFraction Tax percentage measured in basis points. Each basis point represents 0.01%.
     * @param publicGood Flag indicating if the node is a public good.
     * @param endpoint API endpoint of node.
     */
    function createNode(
        address to,
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint
    ) external;

    /**
     * @notice Deletes a node.
     * @param addr The address of node to delete.
     */
    function deleteNode(address addr) external;

    /**
     * @notice Creates a node and deposits tokens.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxFraction Tax percentage measured in basis points. Each basis point represents 0.01%.
     * @param publicGood Flag indicating if the node is a public good.
     * @param endpoint API endpoint of node.
     * @param amount Amount of tokens to deposit.
     */
    function createNodeAndDeposit(
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint,
        uint256 amount
    ) external;

    /**
     * @notice Deposits tokens for node operator.
     * @param amount Amount of tokens to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Requests withdraw tokens from operator pool for node operator.
     * @param amount Amount of tokens to withdraw.
     * @return requestId The created withdraw request id
     */
    function requestWithdrawal(uint256 amount) external returns (uint256 requestId);

    /**
     * @notice Changes tax fraction of the node.
     * @param nodeAddr The address of node to change.
     * @param taxFraction The tax fraction to set.
     * Tax percentage measured in basis points. Each basis point represents 0.01%.
     */
    function setNodeTaxFraction(address nodeAddr, uint64 taxFraction) external;

    /**
     * @notice Sets tax fraction for public pool.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param taxFraction The tax fraction to set.
     */
    function setTaxFraction4PublicPool(uint64 taxFraction) external;

    /**
     * @notice Claims a batch of withdrawal requests.
     */
    function claimWithdrawal(uint256[] calldata requestIds) external;

    /**
     * @notice Stakes tokens to a node operator.
     * @param nodeAddr The address of node to stake.
     * @param amount Amount of tokens to stake.
     * @return startTokenId The start of new minted chips token ids.
     * @return endTokenId The end of new minted chips token ids.
     */
    function stake(address nodeAddr, uint256 amount) external returns (uint256 startTokenId, uint256 endTokenId);

    /**
     * @notice Requests unstake tokens from a node operator.
     * @dev This will burn the chips tokens.
     * @param nodeAddr Address of node operator to unstake.
     * @param chipsIds The chips token ids for unstake.
     * @return requestId THe created unstake request id.
     */
    function requestUnstake(address nodeAddr, uint256[] calldata chipsIds) external returns (uint256 requestId);

    /**
     * @notice Claims a batch of unstake requests.
     * @param requestIds The unstake request ids to claim.
     */
    function claimUnstake(uint256[] calldata requestIds) external;

    /**
     * @notice Stakes tokens to public pool.
     * @param amount Amount of tokens to stake.
     * @return startTokenId The start of new minted chips token ids.
     * @return endTokenId The end of new minted chips token ids.
     */
    function stakeToPublicPool(uint256 amount) external returns (uint256 startTokenId, uint256 endTokenId);

    /**
     * @notice Requests unstake tokens from public pool.
     * @dev This will burn the chips tokens.
     * @param chipsIds The chips token ids for unstake.
     * @return requestId THe created unstake request id.
     */
    function requestUnstakeFromPublicPool(uint256[] calldata chipsIds) external returns (uint256 requestId);

    /**
     * @notice Delegates chips to a public good node.
     * @param chipsIds The chips token ids for delegate.
     */
    function delegate(address nodeAddr, uint256[] calldata chipsIds) external;

    /**
     * @notice Undelegates chips from a public good node.
     * @param chipsIds The chips token ids for undelegate.
     */
    function undelegate(address nodeAddr, uint256[] calldata chipsIds) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param epoch The current epoch number.
     * @param startTime The startTimestamp of the epoch.
     * @param endTime The endTimestamp of the epoch.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param requestFees Amounts of request fees.
     * @param requestBonuses Amounts of request bonuses.
     * @param stakingRewards Amount of staking rewards to reward pool.
     */
    function distributeRewards(
        uint256 epoch,
        uint256 startTime,
        uint256 endTime,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestBonuses,
        uint256[] calldata stakingRewards
    ) external;

    /**
     * @notice Slashes nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs The addresses of nodes to slash.
     */
    function slashNodes(address[] calldata nodeAddrs) external;

    /**
     * @notice Returns the pending withdrawal request by `requestId`.
     * @param requestId The id of withdrawal request.
     * @return DataTypes.WithdrawalRequest The pending withdrawal request.
     */
    function getPendingWithdrawal(uint256 requestId) external view returns (DataTypes.WithdrawalRequest memory);

    /**
     * @notice Returns the pending unstake request by `requestId`.
     * @param requestId The id of unstake request.
     * @return DataTypes.UnstakeRequest The pending unstake request.
     */
    function getPendingUnstake(uint256 requestId) external view returns (DataTypes.UnstakeRequest memory);

    /**
     * @notice Returns the minimal tokens to stake for a node.
     * @param nodeAddr Address of node operator to stake.
     * @return uint256 The minimal mount of tokens to stake for a node .
     */
    function minTokensToStake(address nodeAddr) external view returns (uint256);

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
     * @notice Gets public pool info.
     * @return DataTypes.Node public pool info.
     */
    function getPublicPool() external view returns (DataTypes.Node memory);

    /**
     * @notice Gets total count of nodes.
     * @return uint256 Total count of nodes.
     */
    function getNodeCount() external view returns (uint256);

    /**
     * @notice Gets nodes info by offset and limit.
     * @param offset The offset of nodes to query.
     * @param limit The limit of nodes to query.
     */
    function getNodes(uint256 offset, uint256 limit) external view returns (DataTypes.Node[] memory);

    /**
     * @notice Returns the address of the staking token contract.
     * @return address The address of the staking token contract.
     */
    function stakingToken() external view returns (address);

    /**
     * @notice Returns the address of the chips contract.
     * @return address The address of the chips contract.
     */
    function chipsContract() external view returns (address);
}
