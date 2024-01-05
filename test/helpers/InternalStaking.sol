// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Staking} from "../../src/Staking.sol";

contract InternalStaking is Staking {
    constructor(
        address chips,
        address token,
        uint256 stakeRatio,
        address treasury
    ) Staking(chips, token, stakeRatio, treasury) {}

    function calculateReward(
        uint256 rewards,
        uint64 taxFraction,
        uint256 operatingPool,
        uint256 rewardPool
    ) external view returns (uint256, uint256) {
        return super._getTax(rewards, taxFraction, operatingPool, rewardPool);
    }
}
