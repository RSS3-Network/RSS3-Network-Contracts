// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract SettlementTest is CommonTest, IErrors {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        _setUp();

        vm.deal(alice, 1000000 ether);
        vm.deal(bob, 1000000 ether);
        vm.deal(carol, 1000000 ether);
        vm.deal(dave, 1000000 ether);
        vm.deal(address(_settlement), 30000000 ether);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
        assertEq(_settlement.currentEpoch(), 0);
        assertEq(_settlement.EPOCH_DURATION(), 18 hours);
        assertEq(_settlement.TOTAL_REWARDS_PER_YEAR(), 30000000 ether);
    }

    function testDistributeRewards() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 1000 ether;

        _createNode(alice);
        _createNode(bob);

        vm.prank(alice);
        _staking.deposit{value: depositAmount}();

        vm.prank(bob);
        _staking.deposit{value: depositAmount}();

        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch, ) = _settlement.getBonusInfo();

        uint256 requestFee = 1 ether;
        uint256 operationReward = operationRewardsPerEpoch / 2;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward) // operation rewards
        );

        // check status
    }

    function testDistributeRewardsMultiple() public {
        _createNode(alice);
        _createNode(bob);
        _createNode(carol);
        _createNode(dave);

        vm.prank(alice);
        _staking.deposit{value: 10000 ether}();

        vm.prank(bob);
        _staking.deposit{value: 10000 ether}();

        vm.prank(carol);
        _staking.deposit{value: 10000 ether}();

        vm.prank(dave);
        _staking.deposit{value: 10000 ether}();

        _staking.stake{value: 500 ether}(alice);
        _staking.stake{value: 500 ether}(bob);
        _staking.stake{value: 500 ether}(carol);
        _staking.stake{value: 500 ether}(dave);

        skip(18 hours);

        (uint256 operationRewardsPerEpoch, ) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 4;
        uint256 requestFee = 1 ether;

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward) // operation rewards
        );
        _settlement.distributeRewards(
            1,
            array(carol, dave), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward) // operation rewards
        );
        vm.stopPrank();
    }

    function testDistributeRewardsFailSubmissionIntervalNotElapsed() public {
        _createNode(alice);

        skip(16 hours);

        vm.expectRevert(abi.encodeWithSelector(SubmissionIntervalNotElapsed.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(1 ether), // request fees
            array(100) // operation rewards
        );
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
