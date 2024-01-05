// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettlement {
    /**
     * @notice Initializes the Settlement contract.
     * @param staking Address of the Staking contract.
     * @param oracleAccount Address who makes settlement with the Staking contract.
     * @param startTime The start time of the first epoch.
     * @param requsetBonusPercent The percentage of the total rewards to be allocated to the request bonus.
     * Others will be allocated to the staking rewards.
     */
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 requsetBonusPercent
    ) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param requestFees Amounts of request fees.
     * @param requestCounts Amounts of requests handled by each node.
     */
    function distributeRewards(
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestCounts
    ) external;

    /**
     * @notice Sets tax fraction for public pool.
     * @dev The tax fraction of public pool will be set as the average of tax fractions of active nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs The addresses of active nodes.
     */
    function setTaxFraction4PublicPool(address[] calldata nodeAddrs) external;

    /**
     * @notice Sets request bonus percentage.
     * @param percent The percentage of the total rewards to be allocated to the request bonus.
     * Others will be allocated to the staking rewards.
     */
    function updateRewardsRatio(uint256 percent) external;

    /**
     * @notice Slashes nodes.
     * Requirements:
     * - The caller must have the `ORACLE_ROLE`.
     * @param nodeAddrs The addresses of nodes to slash.
     */
    function slashNodes(address[] calldata nodeAddrs) external;

    /**
     * @notice  Returns the address of the Staking contract.
     * @return Address of the Staking contract.
     */
    function stakingContract() external view returns (address);

    /**
     * @notice  Returns the bonus info.
     * @return (requestBonusPerEpoch, stakingRewardsPerEpoch) The amount of request bonus per epoch.
     */
    function getBonusInfo() external view returns (uint256, uint256);
}
