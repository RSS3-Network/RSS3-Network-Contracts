// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {console} from "forge-std/console.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {Events} from "../src/libraries/Events.sol";

contract SettlementTest is CommonTest, IErrors {
    event Transfer(address indexed from, address indexed to, uint256 value);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    receive() external payable {}

    function setUp() public {
        _setUp();

        vm.deal(alice, 1000000 ether);
        vm.deal(bob, 1000000 ether);
        vm.deal(carol, 1000000 ether);
        vm.deal(dave, 1000000 ether);
        vm.deal(address(_settlement), 390000000 ether);
        vm.deal(oracleAccount, 30000000 ether);
    }

    function invariantTreasuryBalance() public {
        (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens) = _staking.getPoolInfo();
        assertTrue(address(_staking).balance - totalOperationPoolTokens - totalStakingPoolTokens >= 0);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
        assertEq(_settlement.currentEpoch(), 0);
        assertEq(_settlement.EPOCH_DURATION(), 18 hours);
        assertEq(_settlement.TOTAL_REWARDS_PER_YEAR(), 30000000 ether);
    }

    function testUpdateRewardsRatio(uint256 operationRewardsPercent) public {
        vm.assume(operationRewardsPercent >= 0 && operationRewardsPercent <= 100);

        vm.prank(oracleAccount);
        _settlement.updateRewardsRatio(operationRewardsPercent);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();

        uint256 expectedOperationRewardsPerEpoch = (_settlement.TOTAL_REWARDS_PER_YEAR() *
            _settlement.EPOCH_DURATION() *
            operationRewardsPercent) / (100 * 365 days);
        uint256 expectedStakingRewardsPerEpoch = (_settlement.TOTAL_REWARDS_PER_YEAR() *
            _settlement.EPOCH_DURATION() *
            (100 - operationRewardsPercent)) / (100 * 365 days);

        assertEq(operationRewardsPerEpoch, expectedOperationRewardsPerEpoch);
        assertEq(totalStakingRewardsPerEpoch, expectedStakingRewardsPerEpoch);
    }

    function testUpdateRewardsRatioFail() public {
        // caller has no `ORACLE_ROLE` permission
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE));
        _settlement.updateRewardsRatio(1);
    }

    function testSetTaxRateBasisPoints4PublicPool() public {
        vm.prank(alice);
        _staking.createNode("alice", "alice", _defaultTaxRateBasisPoints, false);

        vm.prank(bob);
        _staking.createNode("bob", "bob", _defaultTaxRateBasisPoints * 2, false);

        vm.prank(carol);
        _staking.createNode("carol", "carol", _defaultTaxRateBasisPoints * 3, false);

        vm.prank(dave);
        _staking.createNode("dave", "dave", _defaultTaxRateBasisPoints * 4, false);

        vm.prank(oracleAccount);
        _settlement.setTaxRateBasisPoints4PublicPool(array(alice, bob, carol, dave));

        assertEq(_staking.getPublicPool().taxRateBasisPoints, (_defaultTaxRateBasisPoints * 10) / 4);
    }

    function testSetTaxRateBasisPoints4PublicPoolFail() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE));
        _settlement.setTaxRateBasisPoints4PublicPool(array(alice, bob, carol, dave));

        address[] memory emptyArray;

        vm.expectRevert(abi.encodeWithSelector(EmptyNodeList.selector));
        vm.prank(oracleAccount);
        _settlement.setTaxRateBasisPoints4PublicPool(emptyArray);
    }

    function testDistributeRewards() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        _createNode(alice);
        _createNode(bob);

        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);

        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();

        uint256 operationReward = operationRewardsPerEpoch / 2;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 2;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
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
            array(operationReward, operationReward),
            array(stakingReward, stakingReward)
        );

        // check treasury amount
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, 0);
    }

    function testDistributeRewardsMultiple() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        // create node
        _createNode(alice);
        _createNode(bob);
        _createNode(carol);
        _createNode(dave);

        // deposit
        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);
        _deposit(carol, depositAmount);
        _deposit(dave, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(carol);
        _staking.stake{value: stakeAmount}(dave);

        skip(18 hours);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 4;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 4;

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(operationReward, operationReward), // operation rewards
            false
        );
        assertEq(_staking.isSettlementPhase(), true);

        _settlement.distributeRewards(
            1,
            array(carol, dave), // node addresses
            array(operationReward, operationReward), // operation rewards
            true
        );
        assertEq(_staking.isSettlementPhase(), false);
        vm.stopPrank();

        uint256 taxAmount = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount, depositAmount, depositAmount),
            array(stakeAmount, stakeAmount, stakeAmount, stakeAmount),
            array(alice, bob, carol, dave),
            array(taxAmount, taxAmount, taxAmount, taxAmount),
            array(operationReward, operationReward, operationReward, operationReward),
            array(stakingReward, stakingReward, stakingReward, stakingReward)
        );

        // check treasury amount
        // treasury amount should be 0
        uint256 treasuryAmount = _getTreasuryAmount();
        assertApproxEqAbs(treasuryAmount, 0, 2); // 2 is the max diff
    }

    function testDistributeRewardsWithPartialNodeOffline() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        // create node
        _createNode(alice);
        _createNode(bob);
        _createNode(carol);
        _createNode(dave);

        // deposit
        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);
        _deposit(carol, depositAmount);
        _deposit(dave, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(carol);
        _staking.stake{value: stakeAmount}(dave);

        skip(18 hours);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 4;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 4;

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(operationReward, operationReward), // operation rewards
            true
        );

        uint256 taxAmount = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(alice, bob),
            array(taxAmount, taxAmount),
            array(operationReward, operationReward),
            array(stakingReward, stakingReward)
        );
        // carol and dave are offline, so their rewards should be 0
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(carol, dave),
            array(uint256(0), uint256(0)),
            array(uint256(0), uint256(0)),
            array(uint256(0), uint256(0))
        );

        // check treasury amount
        // stakingRewards and operationRewards of offline nodes will be added to treasury
        uint256 treasuryAmount = _getTreasuryAmount();
        assertApproxEqAbs(treasuryAmount, (stakingReward + operationReward) * 2, 2);
    }

    function testStakingBalanceWithDistributeRewards() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        // create node
        _createNode(alice);
        _createNode(bob);
        _createNode(carol);
        _createNode(dave);

        // deposit
        _deposit(alice, depositAmount + 1);
        _deposit(bob, depositAmount + 2);
        _deposit(carol, depositAmount + 3);
        _deposit(dave, depositAmount + 4);

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount * 2}(bob);
        _staking.stake{value: stakeAmount * 3}(carol);
        _staking.stake{value: stakeAmount * 4}(dave);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 4;

        // distributeRewards
        for (uint256 i = 1; i <= 10; i++) {
            // stake
            _staking.stake{value: stakeAmount * 2}(alice);
            _staking.stake{value: stakeAmount * 2}(bob);
            _staking.stake{value: stakeAmount * 2}(carol);
            _staking.stake{value: stakeAmount * 2}(dave);

            skip(18 hours);

            uint256 balanceBefore = address(_staking).balance;

            vm.startPrank(oracleAccount);
            _settlement.distributeRewards(
                i,
                array(alice, bob), // node addresses
                array(operationReward, operationReward), // operation rewards
                false
            );
            _settlement.distributeRewards(
                i,
                array(carol, dave), // node addresses
                array(operationReward, operationReward), // operation rewards
                true
            );
            vm.stopPrank();

            // check balance
            uint256 balanceAfter = address(_staking).balance;
            uint256 delta = balanceAfter - balanceBefore;
            assertEq(delta, operationRewardsPerEpoch + totalStakingRewardsPerEpoch, "check balance failed");
        }
    }

    function testDistributeRewardsFailNoPermission() public {
        // caller has no `ORACLE_ROLE` permission
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE));
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100), // operation rewards
            false
        );
    }

    function testDistributeRewardsFailInvalidArrayLength() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(100), // operation rewards
            false
        );

        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100, 100), // operation rewards
            false
        );
    }

    function testDistributeRewardsFailSubmissionIntervalNotElapsed() public {
        _createNode(alice);

        skip(16 hours);

        vm.expectRevert(abi.encodeWithSelector(SubmissionIntervalNotElapsed.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100), // operation rewards
            false
        );
    }

    function testDistributeRewardsFailInvalidEpochNumber() public {
        _createNode(alice);
        skip(18 hours);

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100), // operation rewards
            false
        );

        skip(18 hours);

        // case 1, epoch number is less than current epoch
        vm.expectRevert(abi.encodeWithSelector(InvalidEpochNumber.selector, 1, 0));
        _settlement.distributeRewards(
            0,
            array(alice), // node addresses
            array(100), // operation rewards
            false
        );

        // case 2, epoch number is greater than current epoch + 1
        vm.expectRevert(abi.encodeWithSelector(InvalidEpochNumber.selector, 1, 3));
        _settlement.distributeRewards(
            3,
            array(alice), // node addresses
            array(100), // operation rewards
            false
        );
        vm.stopPrank();
    }

    function testDistributeRewardsFailWithOperationRewardsExceedsLimit() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 20000 ether;

        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.addr(i);

            _createNode(user);
            _deposit(user, depositAmount);
            _staking.stake{value: stakeAmount}(user);
        }

        (uint256 operationRewardsPerEpoch, ) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 10;

        for (uint256 i = 1; i <= 9; i++) {
            address user = vm.addr(i);

            skip(18 hours);
            vm.prank(oracleAccount);
            _settlement.distributeRewards(
                1,
                array(user), // node addresses
                array(operationReward), // operation rewards
                false
            );
        }

        skip(18 hours);
        vm.expectRevert(abi.encodeWithSelector(OperationRewardsExceed.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(1, array(vm.addr(10)), array(operationReward + 10), true);
    }

    function testDistributeRewardsFailWithDuplicatedNodeAddr() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 10000 ether;

        // create node
        _createNode(alice);
        _createNode(bob);

        // deposit
        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch, ) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 16;

        vm.startPrank(oracleAccount);
        skip(18 hours);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(operationReward, operationReward), // operation rewards
            false
        );

        vm.expectRevert(abi.encodeWithSelector(RewardsAlreadyDistributed.selector, alice));
        skip(18 hours);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(operationReward), // operation rewards
            false
        );
        vm.stopPrank();
    }

    function testDistributeRewardsWithEmptyEpoch() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 20000 ether;

        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.addr(i);

            _createNode(user);
            _deposit(user, depositAmount);
            _staking.stake{value: stakeAmount}(user);
        }

        // distribute rewards
        uint256 startTime = block.timestamp;
        skip(18 hours);
        uint256 endTime = block.timestamp;

        uint256 balanceBeforeStaking = address(_staking).balance;

        expectEmit();
        emit Events.RewardDistributed(
            1,
            startTime,
            endTime,
            new address[](0),
            new uint256[](0),
            new uint256[](0),
            new uint256[](0)
        );
        vm.prank(oracleAccount);
        _settlement.distributeRewards(1, new address[](0), new uint256[](0), false);

        (uint256 totalOperationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();

        // check balance diff
        uint256 balanceAfterStaking = address(_staking).balance;
        assertEq(
            balanceAfterStaking - balanceBeforeStaking,
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch,
            "check staking balance diff error"
        );

        assertEq(_staking.getPublicPool().stakingPoolTokens, 0, "check public pool balance diff error");

        // check treasury amount
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(
            treasuryAmount,
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch,
            "check treasury amount error"
        );
    }

    function testDistributeRewardsWithPGNWithEmptyEpoch() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 20000 ether;

        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.addr(i);

            _createNode(user);
            _deposit(user, depositAmount);
            _staking.stake{value: stakeAmount}(user);
        }

        _createPublicGoodNode(carol);
        _staking.stakeToPublicPool{value: 10000 ether}(carol);

        // distribute rewards
        uint256 startTime = block.timestamp;
        skip(18 hours);
        uint256 endTime = block.timestamp;

        uint256 pgStakingPoolTokens = _staking.getPublicPool().stakingPoolTokens;
        (, uint256 totalStakingPoolTokens) = _staking.getPoolInfo();
        (uint256 totalOperationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) = _settlement.getBonusInfo();
        uint256 publicPoolReward = (pgStakingPoolTokens * totalStakingRewardsPerEpoch) / totalStakingPoolTokens;

        uint256 balanceBeforeStaking = address(_staking).balance;
        uint256 balanceBeforePublicPool = _staking.getPublicPool().stakingPoolTokens;

        expectEmit();
        emit Events.PublicGoodRewardDistributed(1, startTime, endTime, publicPoolReward, 0);
        expectEmit();
        emit Events.RewardDistributed(
            1,
            startTime,
            endTime,
            new address[](0),
            new uint256[](0),
            new uint256[](0),
            new uint256[](0)
        );
        vm.prank(oracleAccount);
        _settlement.distributeRewards(1, new address[](0), new uint256[](0), false);

        // check balance diff
        uint256 balanceAfterStaking = address(_staking).balance;
        assertEq(
            balanceAfterStaking - balanceBeforeStaking,
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch,
            "check staking balance diff error"
        );

        uint256 balanceAfterPublicPool = _staking.getPublicPool().stakingPoolTokens;
        assertEq(
            balanceAfterPublicPool - balanceBeforePublicPool,
            publicPoolReward,
            "check public pool balance diff error"
        );

        // check treasury amount
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(
            treasuryAmount,
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch - publicPoolReward,
            "check treasury amount error"
        );
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
