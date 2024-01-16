// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Staking} from "../../src/Staking.sol";

contract InternalStaking is Staking {
    constructor(
        address token,
        address treasury,
        uint256 stakeRatio,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        uint256 nodeSlashRateBasisPoints,
        uint256 userSlashRateBasisPoints,
        uint256 minDeposit
    )
        Staking(
            token,
            treasury,
            stakeRatio,
            stakeUnbondingPeriod,
            depositUnbondingPeriod,
            nodeSlashRateBasisPoints,
            userSlashRateBasisPoints,
            minDeposit
        )
    {}

    function calculateReward(
        uint256 rewards,
        uint64 taxRateBasisPoints,
        uint256 operationPool,
        uint256 stakingPool
    ) external view returns (uint256, uint256) {
        return super._getTax(rewards, taxRateBasisPoints, operationPool, stakingPool);
    }
}
