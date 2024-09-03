// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {NodeStatus} from "../libraries/DataTypes.sol";

interface ISettlement {
    /**
     * @notice Initializes the Settlement contract.
     * @param staking Address of the Staking contract.
     * @param oracleAccount Address who makes settlement with the Staking contract.
     * @param startTime The start time of the first epoch.
     * @param operationRewardsPercent The percentage of the total rewards to be allocated to the
     * request bonus.
     * Others will be allocated to the staking rewards.
     */
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 operationRewardsPercent
    ) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @dev This function is periodically called every epoch.
     * @param epoch The current epoch number.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param operationRewards Amounts of operation rewards.
     * @param requestCounts The number of requests each node operator processed.
     * @param isFinal Whether the call is the final one in the epoch.
     */
    function distributeRewards(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata requestCounts,
        bool isFinal
    ) external;

    /**
     * @notice Sets tax fraction for public pool.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param taxRateBasisPoints The basis points of the tax rate to set for the public pool. Each 1
     * base point is
     * 0.01%.
     */
    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external;

    /**
     * @notice Submits demotions for nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`
     * @param nodeAddrs Addresses of node operator to demote.
     * @param reasons The reasons of demotion.
     * @param reporters The reporters of demotion.
     */
    function submitDemotions(
        address[] calldata nodeAddrs,
        string[] calldata reasons,
        address[] calldata reporters
    ) external;

    /**
     * @notice Revokes demotions for a specific node in a given epoch.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddr The address of node to revoke.
     * @param epoch The epoch number.
     * @param demotionIds The ids of demotions to revoke.
     */
    function revokeDemotions(address nodeAddr, uint256 epoch, uint256[] calldata demotionIds)
        external;

    /**
     * @notice Commits slashing for a specific node and epoch.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs The addresses of nodes to commit slashing.
     * @param epochs The epoch number to commit slashing.
     */
    function commitSlashing(address[] calldata nodeAddrs, uint256[] calldata epochs) external;

    /**
     * @notice Sets the status for nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs Addresses of node operator to set.
     * @param status Status to set.
     */
    function setNodeStatus(address[] calldata nodeAddrs, NodeStatus[] calldata status) external;

    /**
     * @notice  Returns the address of the Staking contract.
     * @return Address of the Staking contract.
     */
    function stakingContract() external view returns (address);

    /**
     * @notice Returns the current epoch number.
     * @return uint256 The current epoch number.
     */
    function currentEpoch() external view returns (uint256);

    /**
     * @notice  Returns the bonus info.
     * @return (operationRewardsPerEpoch, stakingRewardsPerEpoch) The amount of request bonus per
     * epoch.
     */
    function getBonusInfo() external view returns (uint256, uint256);
}
