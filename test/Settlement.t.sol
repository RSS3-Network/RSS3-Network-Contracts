// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console,function-max-lines
pragma solidity 0.8.24;

import {Settlement} from "../src/Settlement.sol";
import {Const} from "../src/libraries/Const.sol";
import {Demotion, Node, NodeStatus} from "../src/libraries/DataTypes.sol";
import {
    CommitEpochNotElapsed,
    InvalidArrayLength,
    InvalidEpochNumber,
    OperationRewardsExceed,
    RewardsAlreadyDistributed,
    SubmissionIntervalNotElapsed,
    TaxRateBasisPointsOutOfRange
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";
import {CommonTest} from "./helpers/CommonTest.sol";

contract SettlementTest is CommonTest {
    receive() external payable {}

    function setUp() public {
        _setUp();

        vm.deal(alice, 1_000_000 ether);
        vm.deal(bob, 1_000_000 ether);
        vm.deal(carol, 1_000_000 ether);
        vm.deal(dave, 1_000_000 ether);
        vm.deal(address(_settlement), 390_000_000 ether);
        vm.deal(oracleAccount, 30_000_000 ether);
    }

    function testInitialize() public {
        Settlement s = new Settlement(true);
        s.initialize(address(_staking), address(0), 0, 0);
        assertEq(s.stakingContract(), address(_staking));

        s = new Settlement(true);
        s.initialize(address(_staking), address(0x0), 0, 20);
        (uint256 opRewards,) = s.getBonusInfo();
        uint256 totalStakingRewardsPerEpoch =
            (s.TOTAL_REWARDS_PER_YEAR() * s.EPOCH_DURATION() * 20) / (100 * 365 days);
        assertEq(opRewards, totalStakingRewardsPerEpoch);
    }

    function testSetTaxRateBasisPoints4PublicPool(uint64 taxRate) public {
        taxRate = uint64(bound(taxRate, Const.MIN_TAX_RATE_BASIS_POINTS, Const.DENOMINATOR));

        vm.prank(oracleAccount);
        _settlement.setTaxRateBasisPoints4PublicPool(taxRate);

        assertEq(_staking.getPublicPool().taxRateBasisPoints, taxRate);
    }

    function testSetTaxRateBasisPoints4PublicPoolFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _settlement.setTaxRateBasisPoints4PublicPool(10_001);

        // case 2: TaxRateBasisPointsOutOfRange, tax rate is greater than 10000
        vm.expectRevert(
            abi.encodeWithSelector(TaxRateBasisPointsOutOfRange.selector, uint64(10_001))
        );
        vm.prank(oracleAccount);
        _settlement.setTaxRateBasisPoints4PublicPool(10_001);

        // case 3: TaxRateBasisPointsOutOfRange, tax rate is less than 500
        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsOutOfRange.selector, uint64(400)));
        vm.prank(oracleAccount);
        _settlement.setTaxRateBasisPoints4PublicPool(400);
    }

    function testDistributeRewards() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 10_000 ether;

        _createNode(alice);
        _createNode(bob);

        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);

        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();

        uint256 operationReward = operationRewardsPerEpoch / 2;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 2;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(operationReward, operationReward), // operation rewards
            array(uint256(100), uint256(200)),
            false
        );

        uint256[] memory taxCollected = new uint256[](2);
        taxCollected[0] = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);
        taxCollected[1] = taxCollected[0];

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(alice, bob),
            taxCollected,
            array(operationReward, operationReward),
            array(stakingReward, stakingReward)
        );

        // check treasury amount
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, 0);
    }

    // solhint-disable-next-line function-max-lines
    function testDistributeRewardsMultiple(uint256 depositAmount, uint256 stakeAmount) public {
        // Bound the input values to reasonable ranges
        depositAmount = bound(depositAmount, Const.MIN_DEPOSIT, 100_000 ether);
        stakeAmount = bound(stakeAmount, Const.MIN_STAKE, depositAmount * 6);

        // create 4 nodes with different stake amounts: alice(stakeAmount), bob(stakeAmount*2),
        // carol(stakeAmount*3), dave(stakeAmount*4)
        address[] memory nodes = array(alice, bob, carol, dave);
        for (uint256 i = 0; i < nodes.length; i++) {
            _createNode(nodes[i]);
            _deposit(nodes[i], depositAmount);
            _staking.stake{value: stakeAmount * (i + 1)}(nodes[i]);
        }

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / nodes.length;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 10;

        vm.startPrank(oracleAccount);
        skip(18 hours);

        // Distribute rewards in two batches
        for (uint256 i = 0; i < 2; i++) {
            address[] memory batchNodes = new address[](2);
            uint256[] memory batchOperationRewards = new uint256[](2);
            uint256[] memory batchPerformance = new uint256[](2);

            for (uint256 j = 0; j < 2; j++) {
                batchNodes[j] = nodes[i * 2 + j];
                batchOperationRewards[j] = operationReward;
                batchPerformance[j] = 100 + j * 100; // 100, 200
            }

            _settlement.distributeRewards(
                1,
                batchNodes,
                batchOperationRewards,
                batchPerformance,
                i == 1 // set to true for the last batch
            );

            // Check settlement phase
            assertEq(_staking.isSettlementPhase(), i == 0);
        }
        vm.stopPrank();

        // Prepare arrays for _checkDistribution
        uint256[] memory deposits =
            array(depositAmount, depositAmount, depositAmount, depositAmount);
        uint256[] memory stakes =
            array(stakeAmount, stakeAmount * 2, stakeAmount * 3, stakeAmount * 4);
        uint256[] memory opRewards =
            array(operationReward, operationReward, operationReward, operationReward);
        uint256[] memory stakingRewards =
            array(stakingReward, stakingReward * 2, stakingReward * 3, stakingReward * 4);
        uint256[] memory taxes = array(
            _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints),
            _getFullTax(operationReward + stakingReward * 2, _defaultTaxRateBasisPoints),
            _getFullTax(operationReward + stakingReward * 3, _defaultTaxRateBasisPoints),
            _getFullTax(operationReward + stakingReward * 4, _defaultTaxRateBasisPoints)
        );

        // check status
        _checkDistribution(deposits, stakes, nodes, taxes, opRewards, stakingRewards);

        // check treasury amount
        // all the nodes have collected full tax, so treasury amount should be 0
        uint256 treasuryAmount = _getTreasuryAmount();
        assertApproxEqAbs(treasuryAmount, 0, 2); // 2 is the max diff
    }

    // solhint-disable-next-line function-max-lines
    function testDistributeRewardsWithPartialNodeOffline() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 10_000 ether;

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

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 4;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 4;

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(operationReward, operationReward), // operation rewards
            array(uint256(100), uint256(200)),
            true
        );

        uint256 tax = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(alice, bob),
            array(tax, tax),
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
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 10_000 ether;

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

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();
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
                array(uint256(100), uint256(200)),
                false
            );
            _settlement.distributeRewards(
                i,
                array(carol, dave), // node addresses
                array(operationReward, operationReward), // operation rewards
                array(uint256(100), uint256(200)),
                true
            );
            vm.stopPrank();

            // check balance
            uint256 balanceAfter = address(_staking).balance;
            uint256 delta = balanceAfter - balanceBefore;
            assertEq(
                delta,
                operationRewardsPerEpoch + totalStakingRewardsPerEpoch,
                "check balance failed"
            );
        }
    }

    function testDistributeRewardsToPGN() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        // create node
        _createNode(alice);
        // create public good node
        _createPublicGoodNode(carol);

        // deposit
        _deposit(alice, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stakeToPublicPool{value: stakeAmount}(carol);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 2;
        uint256 stakingReward = totalStakingRewardsPerEpoch / 2;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice, carol), // node addresses
            array(operationReward, operationReward), // operation rewards
            array(uint256(100), uint256(200)),
            true
        );

        uint256 tax = _getFullTax(operationReward + stakingReward, _defaultTaxRateBasisPoints);

        // check status
        _checkDistribution(
            array(depositAmount),
            array(stakeAmount),
            array(alice),
            array(tax),
            array(operationReward),
            array(stakingReward)
        );

        // rewards of PGN is always zero
        assertEq(_staking.getNode(carol).stakingPoolTokens, 0);
        assertEq(_staking.getNode(carol).operationPoolTokens, 0);
    }

    function testDistributeRewardsToNonExistentNode() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        // create node
        _createNode(alice);

        // deposit
        _deposit(alice, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);

        (uint256 operationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(dave), // node addresses
            array(operationRewardsPerEpoch), // operation rewards
            array(uint256(100)),
            true
        );

        // all rewards should be added to treasury
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, operationRewardsPerEpoch + totalStakingRewardsPerEpoch);
    }

    function testDistributeRewardsWithNodeInsufficientDeposit() public {
        uint256 depositAmount = 1000 ether;
        uint256 stakeAmount = 20_000 ether;

        // create node
        _createNode(alice);

        // deposit
        _deposit(alice, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);

        (uint256 totalOperationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();

        uint256 expectedFullTax = _getFullTax(
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch, _defaultTaxRateBasisPoints
        );

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(totalOperationRewardsPerEpoch), // operation rewards
            array(uint256(100)),
            true
        );

        assertEq(
            _staking.getNode(alice).stakingPoolTokens,
            stakeAmount + totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch
                - expectedFullTax
        );
        // operation pool of alice will not change
        assertEq(_staking.getNode(alice).operationPoolTokens, depositAmount);

        // check treasury
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, expectedFullTax);
    }

    function testDistributeRewardsWithFullTax() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        // create node
        _createNode(alice);

        // deposit
        _deposit(alice, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);

        (uint256 operationRewards, uint256 stakingRewards) = _settlement.getBonusInfo();
        uint256 tax = _getFullTax(operationRewards + stakingRewards, _defaultTaxRateBasisPoints);

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(operationRewards), // operation rewards
            array(uint256(100)),
            true
        );

        // check operation pool and staking pool of alice
        assertEq(
            _staking.getNode(alice).stakingPoolTokens,
            stakeAmount + stakingRewards + operationRewards - tax
        );
        assertEq(_staking.getNode(alice).operationPoolTokens, depositAmount + tax);

        // check treasury
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, 0);
    }

    function testDistributeRewardsWithPartialTax() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 300_000 ether;

        // create node
        _createNode(alice);

        // deposit
        _deposit(alice, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);

        (uint256 operationRewards, uint256 stakingRewards) = _settlement.getBonusInfo();
        uint256 fullTax = _getFullTax(operationRewards + stakingRewards, _defaultTaxRateBasisPoints);
        uint256 partialTax = (fullTax * depositAmount * 25) / stakeAmount;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(operationRewards), // operation rewards
            array(uint256(100)),
            true
        );

        // check operation pool and staking pool of alice
        assertEq(
            _staking.getNode(alice).stakingPoolTokens,
            stakeAmount + stakingRewards + operationRewards - fullTax
        );
        assertEq(_staking.getNode(alice).operationPoolTokens, depositAmount + partialTax);

        // check treasury
        // the remaining tax should be added to treasury
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, fullTax - partialTax);
    }

    function testDistributeRewardsFailNoPermission() public {
        // caller has no `ORACLE_ROLE` permission
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100), // operation rewards
            array(uint256(100)),
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
            array(uint256(100), uint256(200)),
            false
        );

        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100, 100), // operation rewards
            array(uint256(100), uint256(200)),
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
            array(uint256(100)),
            false
        );
    }

    function testDistributeRewardsFailSecondSubmissionIntervalNotElapsed() public {
        _createNode(alice);

        vm.startPrank(oracleAccount);
        // epoch 1
        skip(18 hours);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100), // operation rewards
            array(uint256(100)),
            true
        );

        // epoch 2
        skip(16 hours);
        vm.expectRevert(abi.encodeWithSelector(SubmissionIntervalNotElapsed.selector));
        _settlement.distributeRewards(
            2,
            array(alice), // node addresses
            array(100), // operation rewards
            array(uint256(100)),
            true
        );
        vm.stopPrank();
    }

    function testDistributeRewardsFailInvalidEpochNumber() public {
        _createNode(alice);
        skip(18 hours);

        vm.startPrank(oracleAccount);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(100), // operation rewards
            array(uint256(100)),
            false
        );

        skip(18 hours);

        // case 1, epoch number is less than current epoch
        vm.expectRevert(abi.encodeWithSelector(InvalidEpochNumber.selector, 1, 0));
        _settlement.distributeRewards(
            0,
            array(alice), // node addresses
            array(100), // operation rewards
            array(uint256(100)),
            false
        );

        // case 2, epoch number is greater than current epoch + 1
        vm.expectRevert(abi.encodeWithSelector(InvalidEpochNumber.selector, 1, 3));
        _settlement.distributeRewards(
            3,
            array(alice), // node addresses
            array(100), // operation rewards
            array(uint256(100)),
            false
        );
        vm.stopPrank();
    }

    function testDistributeRewardsFailWithOperationRewardsExceedsLimit() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.addr(i);

            _createNode(user);
            _deposit(user, depositAmount);
            _staking.stake{value: stakeAmount}(user);
        }

        (uint256 operationRewardsPerEpoch,) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 10;

        for (uint256 i = 1; i <= 9; i++) {
            address user = vm.addr(i);

            skip(18 hours);
            vm.prank(oracleAccount);
            _settlement.distributeRewards(
                1,
                array(user), // node addresses
                array(operationReward), // operation rewards
                array(uint256(100)),
                false
            );
        }

        skip(18 hours);
        vm.expectRevert(abi.encodeWithSelector(OperationRewardsExceed.selector));
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1, array(vm.addr(10)), array(operationReward + 10), array(uint256(100)), true
        );
    }

    function testDistributeRewardsFailWithDuplicatedNodeAddr() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 10_000 ether;

        // create node
        _createNode(alice);
        _createNode(bob);

        // deposit
        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);

        // stake
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

        (uint256 operationRewardsPerEpoch,) = _settlement.getBonusInfo();
        uint256 operationReward = operationRewardsPerEpoch / 16;

        vm.startPrank(oracleAccount);
        skip(18 hours);
        _settlement.distributeRewards(
            1,
            array(alice, bob), // node addresses
            array(operationReward, operationReward), // operation rewards
            array(uint256(100), uint256(200)),
            false
        );

        vm.expectRevert(abi.encodeWithSelector(RewardsAlreadyDistributed.selector, alice));
        skip(18 hours);
        _settlement.distributeRewards(
            1,
            array(alice), // node addresses
            array(operationReward), // operation rewards
            array(uint256(100)),
            false
        );
        vm.stopPrank();
    }

    function testDistributeRewardsWithEmptyEpoch() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

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
            1, startTime, endTime, zeroAddrArr, zeroUintArr, zeroUintArr, zeroUintArr, zeroUintArr
        );
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            1, new address[](0), new uint256[](0), new uint256[](0), false
        );

        (uint256 totalOperationRewardsPerEpoch, uint256 totalStakingRewardsPerEpoch) =
            _settlement.getBonusInfo();

        // check balance diff
        uint256 balanceAfterStaking = address(_staking).balance;
        assertEq(
            balanceAfterStaking - balanceBeforeStaking,
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch,
            "check staking balance diff error"
        );

        assertEq(
            _staking.getPublicPool().stakingPoolTokens, 0, "check public pool balance diff error"
        );

        // check treasury amount
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(
            treasuryAmount,
            totalOperationRewardsPerEpoch + totalStakingRewardsPerEpoch,
            "check treasury amount error"
        );
    }

    function testDistributeRewardsWithPGNWithEmptyEpoch() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        for (uint256 i = 1; i <= 10; i++) {
            address user = vm.addr(i);

            _createNode(user);
            _deposit(user, depositAmount);
            _staking.stake{value: stakeAmount}(user);
        }

        _createPublicGoodNode(carol);
        _staking.stakeToPublicPool{value: 10_000 ether}(carol);

        // distribute rewards
        uint256 startTime = block.timestamp;
        skip(18 hours);
        uint256 endTime = block.timestamp;

        uint256 pgStakingPoolTokens = _staking.getPublicPool().stakingPoolTokens;
        (, uint256 totalStakingPoolTokens,) = _staking.getPoolInfo();
        (uint256 totalOpRewards, uint256 totalStRewards) = _settlement.getBonusInfo();
        uint256 pgRewards = (pgStakingPoolTokens * totalStRewards) / totalStakingPoolTokens;

        uint256 balanceBeforeStaking = address(_staking).balance;
        uint256 balanceBeforePublicPool = _staking.getPublicPool().stakingPoolTokens;

        expectEmit();
        emit Events.PublicGoodRewardDistributed(1, startTime, endTime, pgRewards, 0);
        expectEmit();
        emit Events.RewardDistributed(
            1, startTime, endTime, zeroAddrArr, zeroUintArr, zeroUintArr, zeroUintArr, zeroUintArr
        );
        vm.prank(oracleAccount);
        _settlement.distributeRewards(1, zeroAddrArr, zeroUintArr, zeroUintArr, false);

        // check balance diff
        uint256 balanceAfterStaking = address(_staking).balance;
        assertEq(balanceAfterStaking - balanceBeforeStaking, totalOpRewards + totalStRewards);

        uint256 balanceAfterPublicPool = _staking.getPublicPool().stakingPoolTokens;
        assertEq(balanceAfterPublicPool - balanceBeforePublicPool, pgRewards);

        // check treasury amount
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, totalOpRewards + totalStRewards - pgRewards);
    }

    function testStakingRewards(uint256 stakingAmount) public {
        stakingAmount = bound(stakingAmount, 500, 10_000);
        stakingAmount = stakingAmount * 1 ether;

        _createNode(alice);
        _createNode(bob);
        _createPublicGoodNode(carol);

        vm.prank(alice);
        _staking.stakeToPublicPool{value: stakingAmount}(carol);

        vm.prank(bob);
        _staking.stake{value: 10_000 ether}(alice);

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

        assertApproxEqAbs(
            sum, _internalSettlementTest.getTotalStakingRewardsPerEpoch(), nodeRewards.length
        );
    }

    function testSubmitDemotions() public {
        _createNode(alice);
        _createNode(bob);

        _presetCurrentEpoch(1);

        // submit demotion
        vm.prank(oracleAccount);
        _settlement.submitDemotions(
            array(alice, bob), array(REASON1, REASON2), array(REPORTER, address(0xffff))
        );

        // check demotions
        Demotion[] memory demotions = _staking.getDemotions(alice, uint256(1));
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(1), alice, uint256(1), REASON1, REPORTER);

        demotions = _staking.getDemotions(bob, uint256(1));
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(2), bob, uint256(1), REASON2, address(0xffff));
    }

    function testSubmitDemotionsFail() public {
        // case 1: caller is not ORACLE_ROLE
        _createNode(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _settlement.submitDemotions(array(alice), array(REASON1), array(REPORTER));
    }

    function testRevokeDemotions() public {
        uint256 epoch = 1;

        _createNode(alice);
        _presetCurrentEpoch(epoch);

        // submit demotion
        vm.prank(oracleAccount);
        _settlement.submitDemotions(array(alice), array(REASON1), array(REPORTER));

        // check demotion
        Demotion[] memory demotions = _staking.getDemotions(alice, epoch);
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(1), alice, epoch, REASON1, REPORTER);

        // revoke demotion
        vm.prank(oracleAccount);
        _settlement.revokeDemotions(alice, epoch, array(uint256(1)));

        // check demotion
        demotions = _staking.getDemotions(alice, epoch);
        assertEq(demotions.length, 0);
    }

    function testRevokeDemotionsFail() public {
        // case 1: caller is not ORACLE_ROLE
        _createNode(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _settlement.revokeDemotions(alice, 1, array(uint256(1)));
    }

    function testCommitSlashing() public {
        _createNode(alice);
        vm.prank(alice);
        _staking.deposit{value: 10_000 ether}();

        _presetCurrentEpoch(uint256(1));

        // submit demotion
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(oracleAccount);
            _settlement.submitDemotions(array(alice), array(REASON1), array(REPORTER));
        }

        skip(Const.SLASHING_COMMIT_PERIOD_IN_EPOCH * 18 hours);
        _presetCurrentEpoch(uint256(4));

        vm.prank(oracleAccount);
        _settlement.commitSlashing(array(alice), array(uint256(1)));

        // check demotions
        Demotion[] memory demotions = _staking.getDemotions(alice, uint256(1));
        assertEq(demotions.length, 4);

        // check node
        Node memory node = _staking.getNode(alice);
        assertEq(node.slashedOperationPoolTokens, 0);
        assertEq(node.slashedStakingPoolTokens, 0);
        assertEq(uint256(node.status), uint256(NodeStatus.Slashed));
        // check slashing pool
        (,, uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, 0);
    }

    function testCommitSlashingFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _settlement.commitSlashing(array(alice), array(uint256(0)));

        // case 2: InvalidArrayLength
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(oracleAccount);
        _settlement.commitSlashing(array(alice), array(uint256(1), uint256(2)));

        // case 3: epoch not reached
        _presetCurrentEpoch(uint256(3));
        vm.expectRevert(
            abi.encodeWithSelector(CommitEpochNotElapsed.selector, uint256(1), uint256(3))
        );
        vm.prank(oracleAccount);
        _settlement.commitSlashing(array(alice), array(uint256(1)));
    }

    function testSetNodeStatusSucceeds() public {
        _createNode(alice);
        vm.prank(alice);
        _staking.deposit{value: 10_000 ether}();

        // Registered -> Initializing
        vm.prank(oracleAccount);
        _settlement.setNodeStatus(array(alice), array(NodeStatus.Initializing));
        // check status
        Node memory node = _staking.getNode(alice);
        assertEq(uint256(node.status), uint256(NodeStatus.Initializing));

        //  Initializing -> Online
        vm.prank(oracleAccount);
        _settlement.setNodeStatus(array(alice), array(NodeStatus.Online));
        // check status
        node = _staking.getNode(alice);
        assertEq(uint256(node.status), uint256(NodeStatus.Online));
    }

    function testSetNodeStatusFail() public {
        // case 1: caller is not ORACLE_ROLE
        address[] memory nodeAddrs = array(alice, bob, carol);
        NodeStatus[] memory status =
            array(NodeStatus.Online, NodeStatus.Offline, NodeStatus.Initializing);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _settlement.setNodeStatus(nodeAddrs, status);
    }

    function invariantTreasuryBalance() public view {
        (
            uint256 totalOperationPoolTokens,
            uint256 totalStakingPoolTokens,
            uint256 totalSlashingPoolTokens
        ) = _staking.getPoolInfo();
        assertTrue(
            address(_staking).balance - totalOperationPoolTokens - totalStakingPoolTokens
                - totalSlashingPoolTokens >= 0
        );
    }

    function testCheckSetupStatus() public view {
        assertEq(_settlement.stakingContract(), address(_staking));
        assertEq(_settlement.currentEpoch(), 0);
        assertEq(_settlement.EPOCH_DURATION(), 18 hours);
        assertEq(_settlement.TOTAL_REWARDS_PER_YEAR(), 30_000_000 ether);
    }

    function _presetCurrentEpoch(uint256 epoch) internal {
        uint256 currentEpochSlot = 5;
        vm.store(address(_settlement), bytes32(uint256(currentEpochSlot)), bytes32(uint256(epoch)));
    }
}
