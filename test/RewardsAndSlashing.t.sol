// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {Const} from "../src/libraries/Const.sol";
import {Demotion, Node, NodeStatus} from "../src/libraries/DataTypes.sol";
import {
    InvalidArrayLength,
    NodeHasNoDemotions,
    NodeIsPublicGood,
    NodeNotExists,
    SlashingNotExist
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";
import {CommonTest} from "./helpers/CommonTest.sol";

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
        uint256 epoch = 4;

        _createNode(alice);
        _presetNodeStatus(alice, NodeStatus.Online);

        expectEmit();
        emit Events.DemotionSubmitted(epoch, alice, uint256(1), REASON1, REPORTER);
        vm.prank(address(_settlement));
        _staking.submitDemotions(epoch, array(alice), array(REASON1), array(REPORTER));

        // check demotion
        Demotion[] memory demotions = _staking.getDemotions(alice, epoch);
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(1), alice, epoch, REASON1, REPORTER);
        // check node status
        assertEq(uint256(_staking.getNode(alice).status), uint256(NodeStatus.Online));
    }

    function testSubmitDemotionsFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));

        // case 2: InvalidArrayLength
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER, address(0xee)));

        // case 3: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(0x111)));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(address(0x111)), array(REASON1), array(REPORTER));

        // case 4: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(0)));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(address(0)), array(REASON1), array(REPORTER));

        // case 5: NodeIsPublicGood
        _createPublicGoodNode(alice);
        vm.expectRevert(abi.encodeWithSelector(NodeIsPublicGood.selector, alice));
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));
    }

    function testRevokeDemotions() public {
        uint256 epoch = 4;

        _createNode(alice);

        // submit demotion
        vm.prank(address(_settlement));
        _staking.submitDemotions(epoch, array(alice), array(REASON1), array(REPORTER));

        Demotion[] memory demotions = _staking.getDemotions(alice, epoch);
        assertEq(demotions.length, 1);
        _checkDemotion(demotions[0], uint256(1), alice, epoch, REASON1, REPORTER);

        // revoke demotion
        vm.prank(address(_settlement));
        _staking.revokeDemotions(alice, epoch, array(uint256(1)));
        demotions = _staking.getDemotions(alice, epoch);
        assertEq(demotions.length, 0);
    }

    function testRevokeDemotionsFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _staking.revokeDemotions(alice, 1, array(uint256(1)));

        // case 2: NodeHasNoDemotion
        vm.expectRevert(abi.encodeWithSelector(NodeHasNoDemotions.selector, alice, 1));
        vm.prank(address(_settlement));
        _staking.revokeDemotions(alice, 1, array(uint256(1)));
    }

    function testRecordSlashing() public {
        uint256 stakedTokens = 40000 ether;
        uint256 depositedTokens = 10000 ether;

        uint256 expectedSlashedStakingPool =
            (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        uint256 expectedSlashedOperationPool =
            (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: depositedTokens}();

        vm.prank(bob);
        uint256 chipId = _staking.stake{value: stakedTokens}(alice);

        _presetNodeStatus(alice, NodeStatus.Online);

        // submit demotion
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(address(_settlement));
            _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));
        }

        expectEmit();
        emit Events.SlashRecorded(
            alice, 1, expectedSlashedOperationPool, expectedSlashedStakingPool
        );
        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Online, NodeStatus.Slashing);
        expectEmit();
        emit Events.DemotionSubmitted(1, alice, uint256(4), REASON1, REPORTER);
        vm.prank(address(_settlement));
        _staking.submitDemotions(1, array(alice), array(REASON1), array(REPORTER));

        // check staking pool and operation tokens
        Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, stakedTokens - expectedSlashedStakingPool);
        assertEq(node.operationPoolTokens, depositedTokens - expectedSlashedOperationPool);
        assertEq(node.slashedOperationPoolTokens, expectedSlashedOperationPool);
        assertEq(node.slashedStakingPoolTokens, expectedSlashedStakingPool);
        // slash status updated correctly
        assertEq(uint256(node.status), uint256(NodeStatus.Slashing));
        // check slashing pool
        (,, uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, expectedSlashedOperationPool + expectedSlashedStakingPool);

        // check chip info
        (, uint256 tokens,) = _staking.getChipInfo(chipId);
        assertEq(tokens, stakedTokens - expectedSlashedStakingPool);
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
        uint256 chipId = _staking.stake{value: stakedTokens}(alice);

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
        (,, uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, 0);

        // check chip info
        (, uint256 tokens,) = _staking.getChipInfo(chipId);
        assertEq(tokens, stakedTokens);
    }

    function testCommitSlashingSucceeds() public {
        uint256 stakedTokens = 40000 ether;
        uint256 depositedTokens = 10000 ether;

        uint256 expectedSlashedStakingPool =
            (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        uint256 expectedSlashedOperationPool =
            (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: depositedTokens}();

        vm.prank(bob);
        uint256 chipId = _staking.stake{value: stakedTokens}(alice);

        _presetNodeStatus(alice, NodeStatus.Online);

        // submit demotions
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(address(_settlement));
            _staking.submitDemotions(1, array(alice), array(REASON1), array(address(0)));
        }

        skip(Const.SLASHING_COMMIT_PERIOD_IN_EPOCH * 18 hours);

        // commit slashing
        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Slashing, NodeStatus.Slashed);
        expectEmit();
        emit Events.SlashCommitted(alice, 1);
        vm.prank(address(_settlement));
        _staking.commitSlashing(alice, 1);

        // check staking pool and operation tokens
        Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, stakedTokens - expectedSlashedStakingPool);
        assertEq(node.operationPoolTokens, depositedTokens - expectedSlashedOperationPool);
        assertEq(node.slashedOperationPoolTokens, 0);
        assertEq(node.slashedStakingPoolTokens, 0);
        // slash status updated correctly
        assertEq(uint256(node.status), uint256(NodeStatus.Slashed));

        // check balances
        uint256 amount = expectedSlashedOperationPool + expectedSlashedStakingPool;
        uint256 burnAmount = (amount * Const.SLASH_BURN_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        assertEq(address(0).balance, burnAmount);

        uint256 reporterAmount =
            (amount * Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        address paymentProcessor = _staking.PAYMENT_PROCESSOR();
        assertEq(paymentProcessor.balance, reporterAmount);

        // check slashing pool
        (,, uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, 0);

        // check chip info
        (, uint256 tokens,) = _staking.getChipInfo(chipId);
        assertEq(tokens, stakedTokens - expectedSlashedStakingPool);
    }

    function testCommitSlashingWithRewards(uint256 depositedTokens, uint256 stakedTokens) public {
        depositedTokens = bound(depositedTokens, 10000, 20000);
        stakedTokens = bound(stakedTokens, 500, 1000);

        depositedTokens *= 1 ether;
        stakedTokens *= 1 ether;

        uint256 expectedSlashedStakingPool =
            (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        uint256 expectedSlashedOperationPool =
            (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) / Const.DENOMINATOR;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: depositedTokens}();

        vm.prank(bob);
        uint256 chipId = _staking.stake{value: stakedTokens}(alice);

        _presetNodeStatus(alice, NodeStatus.Online);

        // submit demotions with reporter
        for (uint256 i = 0; i < 4; i++) {
            vm.prank(address(_settlement));
            _staking.submitDemotions(1, array(alice), array(REASON1), array(address(uint160(i))));
        }

        skip(Const.SLASHING_COMMIT_PERIOD_IN_EPOCH * 18 hours);

        // commit slashing
        vm.prank(address(_settlement));
        _staking.commitSlashing(alice, 1);

        // check staking pool and operation tokens
        Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, stakedTokens - expectedSlashedStakingPool);
        assertEq(node.operationPoolTokens, depositedTokens - expectedSlashedOperationPool);
        assertEq(node.slashedOperationPoolTokens, 0);
        assertEq(node.slashedStakingPoolTokens, 0);
        // slash status updated correctly
        assertEq(uint256(node.status), uint256(NodeStatus.Slashed));

        // check balances
        uint256 amount = expectedSlashedOperationPool + expectedSlashedStakingPool;
        uint256 burnAmount = (amount * Const.SLASH_BURN_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        assertEq(address(0).balance, burnAmount);

        uint256 reporterAmount =
            (amount * Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / Const.DENOMINATOR;
        // check balances of reporters
        assertEq(_staking.PAYMENT_PROCESSOR().balance, reporterAmount / 4);
        for (uint256 i = 1; i < 4; i++) {
            assertEq(address(uint160(i)).balance, reporterAmount / 4);
        }

        // check slashing pool
        (,, uint256 totalSlashingPoolTokens) = _staking.getPoolInfo();
        assertEq(totalSlashingPoolTokens, 0);

        // check chip info
        (, uint256 tokens,) = _staking.getChipInfo(chipId);
        assertEq(tokens, stakedTokens - expectedSlashedStakingPool);
    }

    function testCommitSlashingFail() public {
        // case 1: caller has no `ORACLE_ROLE` permission
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _staking.commitSlashing(alice, uint256(100));

        // case 2: SlashingNotExist
        vm.expectRevert(abi.encodeWithSelector(SlashingNotExist.selector, alice, 100));
        vm.prank(address(_settlement));
        _staking.commitSlashing(alice, uint256(100));
    }
}
