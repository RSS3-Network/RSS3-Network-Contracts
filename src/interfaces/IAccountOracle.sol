// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IAccountOracle {
    /**
     * @notice Initializes the AccountOracle contract.
     * @param staking_ Address of the Staking contract.
     * @param oracleAccount Address who can distribute rewards to the Staking contract.
     */
    function initialize(address staking_, address oracleAccount) external;

    /**
     * @notice Updates accounting stats and distribute rewards.
     * @dev periodically called.
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
}
