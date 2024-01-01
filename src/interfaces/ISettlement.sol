// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ISettlement {
    /**
     * @notice Initializes the AccountOracle contract.
     * @param staking_ Address of the Staking contract.
     * @param oracleAccount Address who makes settlement with the Staking contract.
     */
    function initialize(address staking_, address oracleAccount) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
     * @param epoch The current epoch number.
     * @param startTimestamp The startTimestamp of the epoch.
     * @param endTimestamp The endTimestamp of the epoch.
     * @param totalRequestBonus The total amount of request bonus.
     * @param nodeAddrs Addresses of node operator to receive the rewards.
     * @param requestFees Amounts of request fees.
     * @param requestCounts Amounts of requests handled by each node.
     * @param stakingRewards Amount of staking rewards.
     */
    function distributeRewards(
        uint256 epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 totalRequestBonus,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestCounts,
        uint256[] calldata stakingRewards
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
}
