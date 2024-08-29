// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {CommonTest} from "test/helpers/CommonTest.sol";
import {Const} from "../src/libraries/Const.sol";
import {Node, Demotion, NodeStatus} from "../src/libraries/DataTypes.sol";
import {NodeNotExists, SlashingNotExist, InvalidArrayLength, NodeIsPublicGood} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";

contract RewardsAndSlashingTest is CommonTest {
    function setUp() public {
        _setUp();

        vm.deal(alice, _initialAmount);
        vm.deal(bob, _initialAmount);
        vm.deal(carol, _initialAmount);
        vm.deal(dave, _initialAmount);

        vm.deal(address(_settlement), 30000000 ether);
    }

    function testSubmitDemotions() public {
        _createNode(alice);

        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));

        Demotion[] memory demotions = _staking.getDemotions(alice, uint256(1));
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(1), alice, uint256(1), REASON1, REPORTER);
    }

    function testSubmitDemotionsFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));

        // case 2: InvalidArrayLength
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER, address(0xee)));

        // case 3: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(address(0)), array(REASON1), array(REPORTER));

        // case 4: NodeIsPublicGood
        _createPublicGoodNode(alice);
        vm.expectRevert(abi.encodeWithSelector(NodeIsPublicGood.selector, alice));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));
    }

    function testRevokeDemotions() public {
        _createNode(alice);

        // submit demotion
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));

        Demotion[] memory demotions = _staking.getDemotions(alice, uint256(1));
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(1), alice, uint256(1), REASON1, REPORTER);

        // revoke demotion
        vm.prank(address(_settlement));
        _staking.revokeDemotions(alice, 1, array(uint256(1)));
        demotions = _staking.getDemotions(alice, 1);
        assertEq(demotions.length, 0);
    }

    function testRecordSlashing() public {
        uint256 stakedTokens = 40000 ether;
        uint256 depositedTokens = 10000 ether;

        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) /
            Const.DENOMINATOR;
        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            Const.DENOMINATOR;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: depositedTokens}();

        vm.prank(bob);
        _staking.stake{value: stakedTokens}(alice);

        _presetNodeStatus(alice, NodeStatus.Online);

        // submit demotion
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(address(_settlement));
            _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));
        }

        expectEmit();
        emit Events.SlashRecorded(alice, 1, expectedSlashedTokensOnOperationPool, expectedSlashedTokensOnStakingPool);
        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Online, NodeStatus.Slashing);
        expectEmit();
        emit Events.DemotionSubmitted(1, alice, uint256(4), REASON1, REPORTER);
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));

        // check staking pool and operation tokens
        Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, stakedTokens - expectedSlashedTokensOnStakingPool);
        assertEq(node.operationPoolTokens, depositedTokens - expectedSlashedTokensOnOperationPool);
        assertEq(node.slashedOperationPoolTokens, expectedSlashedTokensOnOperationPool);
        assertEq(node.slashedStakingPoolTokens, expectedSlashedTokensOnStakingPool);
        // slash status updated correctly
        assertEq(uint256(node.status), uint256(NodeStatus.Slashing));
        // check slashing pool
        (, , uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool);
    }

    // Test:
    // 1. Events emitted as expected
    // 2. Slashed tokens returned as expected
    // 3. Slashing info updated as expected
    function testRevokeSlashing() public {
        uint256 stakedTokens = 40000 ether;
        uint256 depositedTokens = 10000 ether;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: depositedTokens}();

        vm.prank(bob);
        _staking.stake{value: stakedTokens}(alice);

        _presetNodeStatus(alice, NodeStatus.Online);

        // submit demotion
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(address(_settlement));
            _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));
        }

        expectEmit();
        emit Events.DemotionRevoked(uint256(3));
        expectEmit();
        emit Events.SlashRevoked(alice, uint256(1));
        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Slashing, NodeStatus.Online);
        vm.prank(address(_settlement));
        _staking.revokeDemotions(alice, uint256(1), array(uint256(3)));

        // check staking pool and operation tokens
        Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, stakedTokens);
        assertEq(node.operationPoolTokens, depositedTokens);
        // slash status updated correctly
        assertEq(uint256(node.status), uint256(NodeStatus.Online));
        assertEq(node.slashedOperationPoolTokens, 0);
        assertEq(node.slashedStakingPoolTokens, 0);
        // check slashing pool
        (, , uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, 0);
    }

    function testCommitSlashingSucceeds() public {
        uint256 stakedTokens = 40000 ether;
        uint256 depositedTokens = 10000 ether;

        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) /
            Const.DENOMINATOR;
        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            Const.DENOMINATOR;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: depositedTokens}();

        vm.prank(bob);
        _staking.stake{value: stakedTokens}(alice);

        _presetNodeStatus(alice, NodeStatus.Online);

        // submit demotions
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(address(_settlement));
            _staking.submitDemotions(1, array(alice), array(REASON1), array(address(0)));
        }

        skip(Const.SLASHING_COMMIT_PERIOD_IN_EPOCH * 18 hours);

        expectEmit();
        emit Events.SlashCommitted(alice, 1);
        vm.prank(address(_settlement));
        _staking.commitSlashing(alice, 1);

        // check staking pool and operation tokens
        Node memory aliceNode = _staking.getNode(alice);
        assertEq(aliceNode.stakingPoolTokens, stakedTokens - expectedSlashedTokensOnStakingPool);
        assertEq(aliceNode.operationPoolTokens, depositedTokens - expectedSlashedTokensOnOperationPool);
        assertEq(aliceNode.slashedOperationPoolTokens, 0);
        assertEq(aliceNode.slashedStakingPoolTokens, 0);
        // slash status updated correctly
        assertEq(uint256(aliceNode.status), uint256(NodeStatus.Slashed));

        // check balances
        uint256 amount = expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool;
        uint256 burnAmount = (amount * Const.SLASH_BURN_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        assertEq(address(0).balance, burnAmount);

        uint256 reporterAmount = (amount * Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        address paymentProcessor = _staking.PAYMENT_PROCESSOR();
        assertEq(paymentProcessor.balance, reporterAmount);

        // check slashing pool
        (, , uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, 0);
    }

    function testCommitSlashingFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE));
        _staking.commitSlashing(alice, uint256(100));

        // case 2: SlashingNotExist
        vm.expectRevert(abi.encodeWithSelector(SlashingNotExist.selector, alice, 100));
        vm.prank(address(_settlement));
        _staking.commitSlashing(alice, uint256(100));
    }
}
