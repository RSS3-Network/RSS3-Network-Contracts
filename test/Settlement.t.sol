// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";

contract SettlementTest is CommonTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        _setUp();

        vm.deal(alice, 100000 ether);
        vm.deal(bob, 100000 ether);
        vm.deal(carol, 100000 ether);
        vm.deal(dave, 100000 ether);
        vm.deal(address(_settlement), 30000000 ether);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
        assertEq(_settlement.currentEpoch(), 1);
        assertEq(_settlement.EPOCH_DURATION(), 18 hours);
        assertEq(_settlement.TOTAL_REWARDS_PER_YEAR(), 30000000 ether);
    }

    function testDistributeRewards() public {
        _createNode(alice);
        _createNode(bob);

        (uint256 operationRewardsPerEpoch, uint256 stakingRewardPerEpoch) = _settlement.getBonusInfo();

        vm.prank(oracleAccount);

        uint256 balBefore = address(_staking).balance;

        _settlement.distributeRewards(
            array(alice, bob), // node addresses
            array(1 ether, 2 ether), // request fees
            array(100, 300) // request counts
        );

        uint256 balAfter = address(_staking).balance;

        console.log(balAfter - balBefore);

        assertEq(balAfter - balBefore, operationRewardsPerEpoch + stakingRewardPerEpoch);

        // TODO: check status
    }

    function testStakingRewards(uint256 stakingAmount) public {
        vm.assume(stakingAmount > 5000 && stakingAmount < 10000);
        stakingAmount = stakingAmount * 1 ether;

        _createNode(alice);
        _createNode(bob);
        _createPublicGoodNode(carol);

        vm.startPrank(alice);
        _staking.stakeToPublicPool{value: stakingAmount}(carol);
        vm.stopPrank();

        vm.startPrank(bob);
        _staking.stake{value: 10000 ether}(alice);
        vm.stopPrank();

        vm.startPrank(carol);
        _staking.stake{value: 8000 ether}(alice);
        vm.stopPrank();

        vm.startPrank(alice);
        _staking.stake{value: stakingAmount}(bob);
        vm.stopPrank();

        vm.startPrank(dave);
        _staking.stake{value: 9000 ether}(bob);
        vm.stopPrank();

        address[] memory nodeAddrs = array(alice, bob);
        (uint256 publicPoolReward, uint256[] memory nodeRewards) = _internalSettlementTest.getStakingRewards(nodeAddrs);

        uint256 sum = publicPoolReward;
        for (uint256 i = 0; i < nodeRewards.length; i++) {
            sum += nodeRewards[i];
        }

        //  we use `nodeRewards.length` here because each node's reward may have the 1wei roundup caused by truncation
        assert(
            sum <= _internalSettlementTest.getTotalStakingRewardsPerEpoch() &&
                sum >= _internalSettlementTest.getTotalStakingRewardsPerEpoch() - nodeRewards.length
        );
    }
}
