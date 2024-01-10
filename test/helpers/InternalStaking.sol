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
        uint256 nodeSlashFraction,
        uint256 userSlashFraction,
        uint256 minDeposit
    )
        Staking(
            token,
            treasury,
            stakeRatio,
            stakeUnbondingPeriod,
            depositUnbondingPeriod,
            nodeSlashFraction,
            userSlashFraction,
            minDeposit
        )
    {}

    function calculateReward(
        uint256 rewards,
        uint64 taxFraction,
        uint256 operatingPool,
        uint256 stakingPool
    ) external view returns (uint256, uint256) {
        return super._getTax(rewards, taxFraction, operatingPool, stakingPool);
    }
}
