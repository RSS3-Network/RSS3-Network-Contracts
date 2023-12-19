// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IStaking {
    /**
     * @notice Create a node operator named `name` with reward address `rewardAddress`.
     * @param name Human-readable name.
     * @param rewardAddress Address which receives rewards for this operator.
     */
    function createNodeOperator(string calldata name, address rewardAddress) external;

    /**
     * @notice Deposit tokens for node operator.
     * @param amount Amount of tokens to stake.
     */
    function stake(uint256 amount) external;

    /**
     * @notice Unstake tokens from node operator.
     * @param amount Amount of tokens to unstake.
     */
    function unstake(uint256 amount) external;

    /**
     * @notice Delegate tokens to a node operator.
     * @param node.
     * @param amount.
     * @return .
     */
    function delegate(address node, uint256 amount) external returns (uint256);

    /**
     * @notice Undelegate tokens from a node operator.
     */
    function undelegate() external returns (uint256);

    /**
     * @notice Updates accounting stats.
     */
    function handleOracleReport() external;
}
