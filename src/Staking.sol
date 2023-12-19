// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IStaking} from "./interfaces/IStaking.sol";

contract Staking is IStaking {
    /// @inheritdoc IStaking
    function createNodeOperator(string calldata name, address rewardAddress) external override {}

    /// @inheritdoc IStaking
    function stake(uint256 amount) external override {}

    /// @inheritdoc IStaking
    function unstake(uint256 amount) external override {}

    /// @inheritdoc IStaking
    function delegate(address node, uint256 amount) external override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IStaking
    function undelegate() external override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IStaking
    function handleOracleReport() external override {}
}
