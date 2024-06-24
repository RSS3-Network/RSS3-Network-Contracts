// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../libraries/DataTypes.sol";

interface IStaking {
    /**
     * @notice Initializes the Staking contract.
     * @param chips Address of the chips contract.
     * @param pauseAccount Address who can pause/unpause the Staking contract.
     * @param oracleAccount Address who can distribute rewards to the Staking contract.
     */
    function initialize(address chips, address pauseAccount, address oracleAccount) external;

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
     * @notice Creates a node and deposits tokens.
     * @param name Human-readable name.
     * @param description Description of node.
     * @param taxRateBasisPoints Tax rate measured in basis points. Each basis point represents 0.01%.
     * @param publicGood Flag indicating if the node is a public good.
     * msg.value carries the amount of tokens to deposit.
     */
    function createNode(
        string calldata name,
        string calldata description,
        uint64 taxRateBasisPoints,
        bool publicGood
    ) external payable;

    /**
     * @notice Updates node name and description.
     * @param name Human-readable name.
     * @param description Description of node.
     */
    function updateNode(string calldata name, string calldata description) external;

    /**
     * @notice Deposits tokens for node operator.
     * msg.value carries the amount of tokens to deposit.
     *
     */
    function deposit() external payable;

    /**
     * @notice Requests withdraw tokens from operation pool for node operator.
     * @param amount Amount of tokens to withdraw.
     * @return requestId The created withdraw request id
     */
    function requestWithdrawal(uint256 amount) external returns (uint256 requestId);

    /**
     * @notice Changes tax rate of the node.
     * @dev Only node operator can call to set tax rate for itself.
     * @param taxRateBasisPoints The basis points of tax rate to set for the node.
     * Each basis point represents 0.01%.
     */
    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints) external;

    /**
     * @notice Sets tax rate for public pool.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param taxRateBasisPoints The basis points of the tax rate to set for the public pool.
     * Each basis point represents 0.01%.
     */
    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external;

    /**
     * @notice Claims a batch of withdrawal requests.
     */
    function claimWithdrawal(uint256[] calldata requestIds) external;

    /**
     * @notice Stakes tokens to a node operator.
     * @param nodeAddr The address of node to stake.
     * @return tokenId The new minted chip token id.
     * msg.value carries the amount of tokens to stake.
     */
    function stake(address nodeAddr) external payable returns (uint256 tokenId);

    /**
     * @notice Requests unstake tokens from a node operator.
     * @dev This will burn the chips tokens.
     * @param nodeAddr Address of node operator to unstake. For public pool, the nodeAddress is address(0).
     * @param chipsIds The chips token ids for unstake.
     * @return requestId The created unstake request id.
     */
    function requestUnstake(address nodeAddr, uint256[] calldata chipsIds) external returns (uint256 requestId);

    /**
     * @notice Claims a batch of unstake requests.
     * @param requestIds The unstake request ids to claim.
     */
    function claimUnstake(uint256[] calldata requestIds) external;

    /**
     * @notice Stakes tokens to public pool.
     * @param nodeAddr The address of node to like.
     * @return tokenId The new minted chip token id.
     * msg.value carries the amount of tokens to stake.
     *
     */
    function stakeToPublicPool(address nodeAddr) external payable returns (uint256 tokenId);

    /**
     * @notice Merges chips tokens into a new one.
     * @dev This will burn the chips tokens and mint a new one.
     * @param chipsIds The chips token ids to merge.
     * @return tokenId The new minted chips token id.
     */
    function mergeChips(uint256[] calldata chipsIds) external returns (uint256 tokenId);

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param epochInfo The current epoch info.
     * - epochInfo[0]: The current epoch number.
     * - epochInfo[1]: The start timestamp of the current epoch.
     * - epochInfo[2]: The end timestamp of the current epoch.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param operationRewards Amounts of request bonuses.
     * @param stakingRewards Amounts of staking rewards to staking pool.
     * @param requestCounts The number of requests each node operator processed.
     * @param publicPoolReward Amount of rewards to public pool.
     */
    function distributeRewards(
        uint256[3] calldata epochInfo,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata stakingRewards,
        uint256[] calldata requestCounts,
        uint256 publicPoolReward
    ) external payable;

    /**
     * @notice Slashes nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs The addresses of nodes to slash.
     */
    function slashNodes(address[] calldata nodeAddrs) external;

    /**
     * @notice Sets the settlement phase.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param enabled Enable/disable the settlement phase.
     */
    function setSettlementPhase(bool enabled) external;

    /**
     * @notice Disable the alpha phase.
     * Requirements:
     * - The caller must have the `PAUSE_ROLE`.
     */
    function disableAlphaPhase() external;

    /**
     * @notice Withdraws tokens from staking contract to treasury.
     */
    function withdraw2Treasury() external;

    /**
     * @notice Returns whether the current time is in settlement phase.
     * @return bool Whether the current time is in settlement phase.
     */
    function isSettlementPhase() external view returns (bool);

    /**
     * @notice Returns whether the current time is in alpha phase.
     * @return bool Whether the current time is in alpha phase.
     */
    function isAlphaPhase() external view returns (bool);

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
     * @notice Gets chip info by `tokenId`.
     * @param tokenId ID of chip token.
     * @return nodeAddr Address of node operator who issues the chip.
     * @return tokens Amount of tokens the chip is equivalent to.
     * @return shares Amount of shares the chip owns.
     */
    function getChipInfo(uint256 tokenId) external view returns (address nodeAddr, uint256 tokens, uint256 shares);

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
     * @notice Gets node info by node address.
     * @param nodeAddr Node address to query.
     * @return DataTypes.Node Node info.
     */
    function getNode(address nodeAddr) external view returns (DataTypes.Node memory);

    /**
     * @notice Gets node avatar data by node address.
     * @param nodeAddr Node address to query.
     * @return string Node avatar info in json.
     */
    function getNodeAvatar(address nodeAddr) external view returns (string memory);

    /**
     * @notice Gets nodes info by node addresses.
     * @param nodeAddrs Node addresses to query.
     * @return DataTypes.Node[] Nodes info.
     */
    function getNodes(address[] calldata nodeAddrs) external view returns (DataTypes.Node[] memory);

    /**
     * @notice Gets nodes info by offset and limit.
     * @param offset The offset of nodes to query.
     * @param limit The limit of nodes to query.
     */
    function getNodesWithPagination(uint256 offset, uint256 limit) external view returns (DataTypes.Node[] memory);

    /**
     * @notice Gets the pool info.
     * @return totalOperationPoolTokens Total tokens in operation pool
     * @return totalStakingPoolTokens Total tokens in staking pool
     */
    function getPoolInfo() external view returns (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens);

    /**
     * @notice Returns the address of the chips contract.
     * @return address The address of the chips contract.
     */
    function chipsContract() external view returns (address);
}
