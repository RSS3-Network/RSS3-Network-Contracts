// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Settlement} from "../../src/Settlement.sol";

contract InternalSettlement is Settlement {
    function getPublicPoolStakingRewards() external view returns (uint256) {
        return super._getPublicPoolStakingRewards();
    }

    function getStakingRewards(address[] calldata nodeAddrs) external view returns (uint256[] memory) {
        return super._getStakingRewards(nodeAddrs);
    }

    function getTotalStakingRewardsPerEpoch() public view returns (uint256) {
        return _totalStakingRewardsPerEpoch;
    }
}
