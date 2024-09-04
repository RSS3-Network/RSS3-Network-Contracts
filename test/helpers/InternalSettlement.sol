// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.24;

import {Settlement} from "../../src/Settlement.sol";

contract InternalSettlement is Settlement {
    constructor() Settlement(true) {}

    function getPublicPoolStakingRewards() external view returns (uint256) {
        return super._getPublicPoolStakingRewards();
    }

    function getStakingRewards(address[] calldata nodeAddrs) external returns (uint256[] memory) {
        return super._getStakingRewards(nodeAddrs);
    }

    function getTotalStakingRewardsPerEpoch() public view returns (uint256) {
        return _totalStakingRewardsPerEpoch;
    }
}
