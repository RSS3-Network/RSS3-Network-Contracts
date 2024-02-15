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
        vm.deal(oracleAccount, 30000000 ether);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
        assertEq(_settlement.currentEpoch(), 0);
        assertEq(_settlement.EPOCH_DURATION(), 18 hours);
        assertEq(_settlement.TOTAL_REWARDS_PER_YEAR(), 30000000 ether);
    }

    function testDistributeRewards() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        _createNode(alice);
        _createNode(bob);

        vm.prank(alice);
        _staking.deposit{value: depositAmount}();

        vm.prank(bob);
        _staking.deposit{value: depositAmount}();

        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();

        uint256 requestFee = 10 ether;
        uint256 operationReward = operationRewardsPerEpoch / 2;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 2;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards{value: requestFee * 2}(
            1,
            array(alice, bob), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward), // operation rewards
            false
        );

        uint256[] memory taxAmounts = new uint256[](2);
        taxAmounts[0] = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);
        taxAmounts[1] = taxAmounts[0];

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(alice, bob),
            taxAmounts,
            array(requestFee, requestFee),
            array(operationReward, operationReward),
            array(stakingReward, stakingReward)
        );
    }

    function testDistributeRewardsMultiple() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        _createNode(alice);
        _createNode(bob);
        _createNode(carol);
        _createNode(dave);

        vm.prank(alice);
        _staking.deposit{value: depositAmount}();

        vm.prank(bob);
        _staking.deposit{value: depositAmount}();

        vm.prank(carol);
        _staking.deposit{value: depositAmount}();

        vm.prank(dave);
        _staking.deposit{value: depositAmount}();

        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(carol);
        _staking.stake{value: stakeAmount}(dave);

        skip(18 hours);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();
        uint256 requestFee = 100 ether;
        uint256 operationReward = operationRewardsPerEpoch / 4;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 4;

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards{value: requestFee * 2}(
            1,
            array(alice, bob), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward), // operation rewards
            false
        );

        assertEq(_staking.isSettlementPhase(), true);

        _settlement.distributeRewards{value: requestFee * 2}(
            1,
            array(carol, dave), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward), // operation rewards
            true
        );

        assertEq(_staking.isSettlementPhase(), false);

        vm.stopPrank();

        uint256 taxAmount = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(alice, bob),
            array(taxAmount, taxAmount),
            array(requestFee, requestFee),
            array(operationReward, operationReward),
            array(stakingReward, stakingReward)
        );
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(carol, dave),
            array(taxAmount, taxAmount),
            array(requestFee, requestFee),
            array(operationReward, operationReward),
            array(stakingReward, stakingReward)
        );
    }

    function testDistributeRewardsFailSubmissionIntervalNotElapsed() public {
        uint256 requestFee = 1 ether;

        _createNode(alice);

        skip(16 hours);

        vm.expectRevert(abi.encodeWithSelector(SubmissionIntervalNotElapsed.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards{value: requestFee}(
            1,
            array(alice), // node addresses
            array(requestFee), // request fees
            array(100), // operation rewards
            false
        );
    }

    function testDistributeRewardsFailInvalidEpochNumber() public {
        _createNode(alice);
        skip(18 hours);

        uint256 requestFee = 1 ether;

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards{value: requestFee}(
            1,
            array(alice), // node addresses
            array(requestFee), // request fees
            array(100), // operation rewards
            false
        );

        skip(18 hours);

        vm.expectRevert(abi.encodeWithSelector(InvalidEpochNumber.selector));
        _settlement.distributeRewards(
            0,
            array(alice), // node addresses
            array(1 ether), // request fees
            array(100), // operation rewards
            false
        );
        vm.stopPrank();
    }

    function testDistributeRewardsFailWithOperationRewardsExceedsLimit() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        uint256 requestFee = 1 ether;

        // create node
        _createNode(alice);
        _createNode(bob);
        _createNode(carol);

        // deposit
        vm.prank(alice);
        _staking.deposit{value: depositAmount}();

        vm.prank(bob);
        _staking.deposit{value: depositAmount}();

        vm.prank(carol);
        _staking.deposit{value: depositAmount}();

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(carol);

        (uint256 operationRewardsPerEpoch, ) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 3;

        skip(18 hours);

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards{value: requestFee * 2}(
            1,
            array(alice, bob), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward), // operation rewards
            false
        );

        skip(18 hours);

        vm.expectRevert(abi.encodeWithSelector(OperationRewardsExceed.selector));
        _settlement.distributeRewards{value: requestFee}(
            1,
            array(carol), // node addresses
            array(requestFee), // request fees
            array(operationReward * 2), // operation rewards
            false
        );
        vm.stopPrank();
    }

    function testDistributeRewardsFailWithDuplicatedNodeAddr() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        uint256 requestFee = 1 ether;

        // create node
        _createNode(alice);
        _createNode(bob);

        // deposit
        vm.prank(alice);
        _staking.deposit{value: depositAmount}();

        vm.prank(bob);
        _staking.deposit{value: depositAmount}();

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch, ) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 16;

        vm.startPrank(oracleAccount);
        skip(18 hours);
        _settlement.distributeRewards{value: requestFee * 2}(
            1,
            array(alice, bob), // node addresses
            array(requestFee, requestFee), // request fees
            array(operationReward, operationReward), // operation rewards
            false
        );

        vm.expectRevert(abi.encodeWithSelector(RewardsAlreadyDistributed.selector, alice));
        skip(18 hours);
        _settlement.distributeRewards{value: requestFee * 2}(
            1,
            array(alice), // node addresses
            array(requestFee), // request fees
            array(operationReward), // operation rewards
            false
        );
        vm.stopPrank();
    }

    function testStakingRewards(uint256 stakingAmount) public {
        vm.assume(stakingAmount > 5000 && stakingAmount < 10000);
        stakingAmount = stakingAmount * 1 ether;

        _createNode(alice);
        _createNode(bob);
        _createPublicGoodNode(carol);

        vm.prank(alice);
        _staking.stakeToPublicPool{value: stakingAmount}(carol);

        vm.prank(bob);
        _staking.stake{value: 10000 ether}(alice);

        vm.prank(carol);
        _staking.stake{value: 8000 ether}(alice);

        vm.prank(alice);
        _staking.stake{value: stakingAmount}(bob);

        vm.prank(dave);
        _staking.stake{value: 9000 ether}(bob);

        address[] memory nodeAddrs = array(alice, bob);
        uint256 publicPoolReward = _internalSettlementTest.getPublicPoolStakingRewards();
        uint256[] memory nodeRewards = _internalSettlementTest.getStakingRewards(nodeAddrs);

        uint256 sum = publicPoolReward;
        for (uint256 i = 0; i < nodeRewards.length; i++) {
            sum += nodeRewards[i];
        }

        assertApproxEqAbs(sum, _internalSettlementTest.getTotalStakingRewardsPerEpoch(), nodeRewards.length);
    }
}
