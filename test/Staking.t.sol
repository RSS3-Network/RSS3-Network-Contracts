// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.24;

import {Staking} from "../src/Staking.sol";
import {IERC721Errors} from "../src/interfaces/IERC721Errors.sol";
import {Const} from "../src/libraries/Const.sol";
import {Node, NodeStatus, UnstakeRequest, WithdrawalRequest} from "../src/libraries/DataTypes.sol";
import {
    ChipIdsArrayTooSmall,
    ChipNotValid,
    ChipsNotSameOwner,
    ClaimIdNotExists,
    ClaimTimeNotReady,
    DepositForPublicGoodNode,
    EmptyChipIds,
    ExcessWithdrawalAmount,
    InvalidArrayLength,
    NodeInExitStatus,
    NodeNotExists,
    NodeNotPublicGood,
    SettlementPhase,
    StakeAmountTooSmall,
    StakeToPublicGoodNode,
    WithdrawalAmountExceedsOperationPoolTokens
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";
import {RewardsAndSlashingLib} from "../src/libraries/RewardsAndSlashingLib.sol";
import {CommonTest} from "./helpers/CommonTest.sol";
import {TestEvents} from "./helpers/TestEvents.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {Base64} from "solady/utils/Base64.sol";
import {LibString} from "solady/utils/LibString.sol";

// import {console2 as console} from "forge-std/console2.sol";

contract StakingTest is CommonTest, IERC721Errors {
    using stdJson for string;

    function setUp() public {
        _setUp();

        vm.deal(alice, _initialAmount);
        vm.deal(bob, _initialAmount);
        vm.deal(carol, _initialAmount);
        vm.deal(dave, _initialAmount);

        vm.deal(address(_settlement), 30_000_000 ether);
    }

    function testPause() public {
        // expect events
        expectEmit(CheckAll);
        emit Paused(pauseAccount);
        vm.prank(pauseAccount);
        _staking.pause();

        // check paused
        assertEq(_staking.paused(), true);
    }

    function testPauseFail() public {
        // case 1: caller is not PAUSE_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), PAUSE_ROLE
            )
        );
        _staking.pause();
        // check paused
        assertEq(_staking.paused(), false);

        // pause staking contract
        vm.startPrank(pauseAccount);
        _staking.pause();
        // case 2: staking contract has been paused
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.pause();
        vm.stopPrank();
    }

    function testUnpause() public {
        vm.prank(pauseAccount);
        _staking.pause();
        // check paused
        assertEq(_staking.paused(), true);

        // expect events
        expectEmit(CheckAll);
        emit Unpaused(pauseAccount);
        vm.prank(pauseAccount);
        _staking.unpause();

        // check paused
        assertEq(_staking.paused(), false);
    }

    function testUnpauseFail() public {
        // case 1: _staking not paused
        vm.expectRevert(abi.encodeWithSelector(ExpectedPause.selector));
        _staking.unpause();
        // check paused
        assertEq(_staking.paused(), false);

        // case 2: caller has no `PAUSE_ROLE` permission
        vm.prank(pauseAccount);
        _staking.pause();
        // check paused
        assertEq(_staking.paused(), true);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), PAUSE_ROLE
            )
        );
        _staking.unpause();
        // check paused
        assertEq(_staking.paused(), true);
    }

    function testDoFailWhenPaused() public {
        // users can't do specific operations when the contract is paused
        vm.prank(pauseAccount);
        _staking.pause();

        // case 1: create node
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.createNode("Alice", "Alice's node", 100, false);

        // case 2: deposit
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.deposit{value: 100}();

        // case 3: request withdrawal
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.requestWithdrawal(100);

        // case 4: claim withdrawal
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.claimWithdrawal(new uint256[](0));

        // case 5: set tax rate
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.setTaxRateBasisPoints4Node(100);

        // case 6: stake
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.stake{value: 100}(alice);

        // case 7: stake to public pool
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.stakeToPublicPool{value: 100}(alice);

        // case 8: unstake
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.requestUnstake(alice, new uint256[](1));

        // case 9: claim unstake
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.claimUnstake(new uint256[](1));
    }

    function testDeposit(uint256 amount) public {
        amount = bound(amount, 1 ether, 100_000 ether);

        _createNode(alice);

        expectEmit();
        emit Events.Deposited(alice, amount);
        vm.prank(alice);
        _staking.deposit{value: amount}();

        Node memory node = _staking.getNode(alice);
        assertEq(node.operationPoolTokens, amount);

        // check node status
        NodeStatus expectedStatus =
            amount >= Const.MIN_DEPOSIT ? NodeStatus.Registered : NodeStatus.None;
        assertEq(uint256(_staking.getNode(alice).status), uint256(expectedStatus));
    }

    function testDepositAfterExit() public {
        uint256 amount = 10_000 ether;

        vm.startPrank(alice);
        _staking.createNode("Name", "Description", _defaultTaxRateBasisPoints, false);
        _staking.deposit{value: 2 * amount}();

        _staking.exit();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));

        _staking.requestWithdrawal(2 * amount);

        // op pool < min deposit
        _staking.deposit{value: amount / 2}();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));

        // op pool > min deposit
        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Exited, NodeStatus.Registered);
        _staking.deposit{value: amount / 2}();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));
        vm.stopPrank();
    }

    function testDepositFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.deposit{value: 1}();
    }

    function testDepositFailWithPublicGoodNodeDeposited() public {
        _staking.createNode("Alice", "Alice's node", uint64(0), true);

        vm.expectRevert(abi.encodeWithSelector(DepositForPublicGoodNode.selector));
        _staking.deposit{value: 1}();
    }

    function testRequestWithdrawalSucceeds() public {
        uint256 depositAmount = 100_000 ether;
        uint256 withdrawalAmount = depositAmount / 2 + 1;

        vm.startPrank(alice);
        _staking.createNode{value: depositAmount}("Alice", "Alice's node", uint64(1000), false);

        vm.expectEmit();
        emit Events.WithdrawRequested(alice, withdrawalAmount, 1);
        uint256 requestId = _staking.requestWithdrawal(withdrawalAmount);

        // requestWithdrawal again will fail
        vm.expectRevert(abi.encodeWithSelector(WithdrawalAmountExceedsOperationPoolTokens.selector));
        _staking.requestWithdrawal(withdrawalAmount);
        vm.stopPrank();

        // check status
        WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, withdrawalAmount);

        // check node info
        Node memory node = _staking.getNode(alice);
        assertEq(node.operationPoolTokens, depositAmount - withdrawalAmount);
    }

    function testRequestWithdrawalSucceedsWithExit() public {
        uint256 depositAmount = 20_000 ether;

        vm.startPrank(alice);
        // create node and deposit
        _staking.createNode("Alice", "Alice's node", uint64(1000), false);

        // node in these status can initiate exit
        NodeStatus[] memory status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Online,
            NodeStatus.Outdated,
            NodeStatus.Slashed
        );
        for (uint256 i = 0; i < status.length; i++) {
            if (status[i] != NodeStatus.Online) {
                _staking.deposit{value: depositAmount}();
            }

            // preset node status
            _presetNodeStatus(alice, status[i]);

            NodeStatus expectedStatus =
                status[i] == NodeStatus.Online ? NodeStatus.Exiting : NodeStatus.Exited;
            // exit
            _staking.exit();

            // check new status
            assertEq(uint256(_staking.getNode(alice).status), uint256(expectedStatus));

            // request withdrawal
            if (expectedStatus == NodeStatus.Exited) {
                uint256 requestId = _staking.requestWithdrawal(depositAmount);
                WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
                assertEq(req.owner, alice);
                assertEq(req.timestamp, block.timestamp);
                assertEq(req.amount, depositAmount);

                // check node info
                assertEq(_staking.getNode(alice).operationPoolTokens, 0);
            }
        }
        vm.stopPrank();
    }

    function testMultipleDepositAndRequestWithdrawal() public {
        uint256 amount = 10_000 ether;

        vm.startPrank(alice);
        _staking.createNode{value: amount}("Alice", "Alice's node", uint64(1000), false);

        _staking.deposit{value: amount}();

        _staking.exit();
        skip(Const.NODE_EXIT_PERIOD);

        uint256 requestId = _staking.requestWithdrawal(2 * amount);
        vm.stopPrank();

        // check status
        WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, 2 * amount);
    }

    function testRequestWithdrawalFailWithInsufficientTokens() public {
        uint256 amount = 10_000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        // case 1: ExcessWithdrawalAmount
        vm.expectRevert(abi.encodeWithSelector(WithdrawalAmountExceedsOperationPoolTokens.selector));
        _staking.requestWithdrawal(amount + 1);

        // case 2: ExcessWithdrawalAmount
        _presetNodeStatus(alice, NodeStatus.Online);
        _staking.exit();
        vm.expectRevert(abi.encodeWithSelector(ExcessWithdrawalAmount.selector));
        _staking.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function testRequestWithdrawalFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.requestWithdrawal(1 ether);
    }

    function testClaimWithdrawal() public {
        uint256 amount = 10_000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: amount}();
        _staking.exit();
        skip(Const.NODE_EXIT_PERIOD);

        uint256 requestId = _staking.requestWithdrawal(amount);

        uint256[] memory requestIds = array(requestId);

        vm.expectRevert(abi.encodeWithSelector(ClaimTimeNotReady.selector));
        _staking.claimWithdrawal(requestIds);

        skip(depositUnbondingPeriod);

        expectEmit();
        emit Events.WithdrawalClaimed(requestId, alice, amount);
        _staking.claimWithdrawal(requestIds);

        // Claim again will fail
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, requestId));
        _staking.claimWithdrawal(requestIds);

        vm.stopPrank();
    }

    function testMultipleRequestAndClaimWithdrawal() public {
        _createNode(alice);

        uint256 depositAmount = 10_000 ether;

        vm.startPrank(alice);
        _staking.deposit{value: depositAmount}();

        uint256 withdrawAmount = 10 ether;
        assertEq(depositAmount % withdrawAmount, 0);

        _staking.exit();
        skip(Const.NODE_EXIT_PERIOD);

        uint256[] memory requestIds = new uint256[](depositAmount / withdrawAmount);
        for (uint256 i = 0; i < requestIds.length; i++) {
            requestIds[i] = _staking.requestWithdrawal(withdrawAmount);
        }

        skip(depositUnbondingPeriod);

        _staking.claimWithdrawal(requestIds);

        vm.stopPrank();
    }

    function testSetSettlementPhase() public {
        vm.startPrank(address(_settlement));
        _staking.setSettlementPhase(true);
        assertEq(_staking.isSettlementPhase(), true);

        _staking.setSettlementPhase(false);
        assertEq(_staking.isSettlementPhase(), false);
        vm.stopPrank();
    }

    function testSetSettlementPhaseFail() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                address(this),
                0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1
            )
        );
        _staking.setSettlementPhase(true);
    }

    function testStake(uint256 amount) public {
        amount = bound(amount, 500 ether, _initialAmount);

        _createNode(alice);

        expectEmit();
        emit TestEvents.Transfer(address(0), bob, 1);
        expectEmit();
        emit Events.Staked(bob, alice, amount, 1, 1);
        vm.prank(bob);
        uint256 tokenId = _staking.stake{value: amount}(alice);

        Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, amount);
        assertEq(node.totalShares, amount);

        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(tokenId);
        assertEq(nodeAddr, alice);
        assertEq(tokens, amount);
        assertEq(shares, amount);
    }

    function testStakeFailToNonExistentNode() public {
        // stake to a non-existent node will fail
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, alice));
        _staking.stake{value: 1000 ether}(alice);
    }

    function testStakeFailToPublicGoodNode() public {
        _createPublicGoodNode(alice);

        vm.expectRevert(abi.encodeWithSelector(StakeToPublicGoodNode.selector, alice));
        _staking.stake{value: 1}(alice);
    }

    function testStakeFailWithAmountTooSmall() public {
        _createNode(alice);

        // case 1: stake 0
        vm.expectRevert(abi.encodeWithSelector(StakeAmountTooSmall.selector));
        _staking.stake{value: 0}(alice);

        // case 2: stake amount is less than 500
        vm.expectRevert(abi.encodeWithSelector(StakeAmountTooSmall.selector));
        _staking.stake{value: 499 ether}(alice);
    }

    function testStakeFailInSettlementPhase() public {
        _createNode(alice);

        vm.prank(address(_settlement));
        _staking.setSettlementPhase(true);

        vm.expectRevert(abi.encodeWithSelector(SettlementPhase.selector));
        _staking.stake{value: 10_000 ether}(alice);
    }

    function testStakeFailWithNodeInExitStatus() public {
        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: 10_000 ether}();
        _staking.exit();
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(NodeInExitStatus.selector));
        _staking.stake{value: 10_000 ether}(alice);
    }

    function testStakeToPublicPool(uint256 amount) public {
        amount = bound(amount, 500 ether, _initialAmount);

        _createPublicGoodNode(alice);

        vm.prank(bob);
        uint256 tokenId = _staking.stakeToPublicPool{value: amount}(alice);

        assertEq(_staking.getPublicPool().stakingPoolTokens, amount);
        assertEq(_staking.getPublicPool().totalShares, amount);

        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(tokenId);
        assertEq(nodeAddr, alice);
        assertEq(tokens, amount);
        assertEq(shares, amount);
    }

    function testStakeToPublicPoolFailToNonPublicGoodNode() public {
        // stake to public pool with non public good node will fail
        _createNode(bob);

        vm.expectRevert(abi.encodeWithSelector(NodeNotPublicGood.selector, bob));
        _staking.stakeToPublicPool{value: 1}(bob);
    }

    function testStakeToPublicPoolFailWithStakeAmountTooSmall() public {
        _createPublicGoodNode(alice);

        // stake to public pool with zero amount will fail
        vm.expectRevert(abi.encodeWithSelector(StakeAmountTooSmall.selector));
        _staking.stakeToPublicPool{value: 0}(alice);
    }

    function testStakeToPublicPoolFailInSettlementPhase() public {
        _createPublicGoodNode(alice);

        vm.prank(address(_settlement));
        _staking.setSettlementPhase(true);

        vm.expectRevert(abi.encodeWithSelector(SettlementPhase.selector));
        _staking.stakeToPublicPool{value: 10_000 ether}(alice);
    }

    function testRequestUnstakeFromPublic() public {
        _createPublicGoodNode(alice);

        // stake and then request unstake
        _testRequestUnstakeFromNode(alice, true);
    }

    function testRequestUnstake() public {
        _createNode(alice);
        // stake and then request unstake
        _testRequestUnstakeFromNode(alice, false);
    }

    function testRequestUnstakeApprovedChip() public {
        _createNode(alice);
        // stake and then request unstake
        _testRequestUnstakeApprovedChipFromNode(alice, false);
    }

    function testRequestUnstakeWithTransferChip() public {
        uint256 amount = 10_000 ether;

        _createNode(alice);

        vm.startPrank(bob);
        _staking.stake{value: amount}(alice);
        _staking.stake{value: amount * 2}(alice);
        // bob transfers chips to carol
        _chips.transferFrom(bob, carol, 1);
        _chips.transferFrom(bob, carol, 2);
        vm.stopPrank();

        // request unstake
        vm.prank(carol);
        uint256 requestId = _staking.requestUnstake(alice, array(uint256(1), uint256(2)));

        // check status
        UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, carol);
        assertEq(req.nodeAddr, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount * 3);
    }

    function testRequestUnstakeApprovedChipsFromPublicGoodNode() public {
        _createPublicGoodNode(alice);

        _testRequestUnstakeApprovedChipsFromNode(alice, true);
    }

    function testRequestUnstakeApprovedChipFromPublicGoodNode() public {
        _createPublicGoodNode(alice);

        _testRequestUnstakeApprovedChipFromNode(alice, true);
    }

    function testRequestUnstakeFailInEmptyChipsIds() public {
        _createNode(alice);

        vm.expectRevert(abi.encodeWithSelector(EmptyChipIds.selector));
        _staking.requestUnstake(alice, new uint256[](0));
    }

    function testRequestUnstakeFailInChipsNotSameOwner() public {
        _createNode(alice);

        vm.startPrank(bob);
        uint256 t1 = _staking.stake{value: 10_000 ether}(alice);
        _chips.approve(carol, t1);

        vm.startPrank(carol);
        uint256 t2 = _staking.stake{value: 10_000 ether}(alice);

        vm.expectRevert(abi.encodeWithSelector(ChipsNotSameOwner.selector));
        _staking.requestUnstake(alice, array(t1, t2));
        vm.stopPrank();
    }

    function testRequestUnstakeFailInSettlementPhase() public {
        _createNode(alice);

        _staking.stake{value: 5000 ether}(alice);

        vm.prank(address(_settlement));
        _staking.setSettlementPhase(true);

        vm.expectRevert(abi.encodeWithSelector(SettlementPhase.selector));
        _staking.requestUnstake(alice, array(1));
    }

    function testRequestUnstakeFailWithBurnedChip() public {
        uint256 amount = 10_000 ether;

        _createNode(alice);

        // stake
        vm.startPrank(bob);
        uint256 tokenId = _staking.stake{value: amount}(alice);

        // request unstake
        _staking.requestUnstake(alice, array(tokenId));

        // requestUnstake again will fail
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenId));
        _staking.requestUnstake(alice, array(tokenId));
        vm.stopPrank();
    }

    function testClaimUnstake(uint256 amount) public {
        amount = bound(amount, 500 ether, _initialAmount);

        _createNode(alice);

        vm.startPrank(bob);
        // stake
        uint256 tokenId = _staking.stake{value: amount}(alice);
        // request unstake
        uint256 requestId = _staking.requestUnstake(alice, array(tokenId));
        uint256[] memory requestIds = array(requestId);

        // claim unstake
        skip(stakeUnbondingPeriod);

        expectEmit();
        emit Events.UnstakeClaimed(requestId, alice, bob, amount);
        _staking.claimUnstake(requestIds);

        // claim again will fail
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, requestId));
        _staking.claimUnstake(requestIds);

        vm.stopPrank();

        // check balances
        assertEq(bob.balance, _initialAmount);

        UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, address(0));
        assertEq(req.nodeAddr, address(0));
        assertEq(req.timestamp, 0);
        assertEq(req.unstakeAmount, 0);
    }

    function testClaimUnstakeFail() public {
        _createNode(alice);

        vm.startPrank(bob);

        // case 1: claim id not exists
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, uint256(1)));
        _staking.claimUnstake(array(uint256(1)));

        uint256 tokenId = _staking.stake{value: 10_000 ether}(alice);
        uint256 requestId = _staking.requestUnstake(alice, array(tokenId));

        // case 2: claim time not ready
        vm.expectRevert(abi.encodeWithSelector(ClaimTimeNotReady.selector));
        _staking.claimUnstake(array(requestId));

        vm.stopPrank();
    }

    function testRequestUnstakeWithMergedChips() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        _createNode(bob);
        _deposit(bob, depositAmount);

        vm.startPrank(alice);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(bob);

        uint256 balBefore = alice.balance;

        uint256 newChipId = _staking.mergeChips(array(uint256(1), uint256(2)));
        assertEq(newChipId, uint256(4));

        uint256 requestId = _staking.requestUnstake(bob, array(uint256(3), uint256(4)));
        skip(22.5 days);
        _staking.claimUnstake(array(requestId));
        vm.stopPrank();

        // check status
        uint256 balAfter = alice.balance;
        assertEq(balAfter - balBefore, stakeAmount * 3);

        UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, address(0));
        assertEq(req.nodeAddr, address(0));
        assertEq(req.timestamp, 0);
        assertEq(req.unstakeAmount, 0);

        // check node
        Node memory node = _staking.getNode(bob);
        assertEq(node.stakingPoolTokens, 0);
    }

    function testMergeChips() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;

        _createNode(bob);
        _deposit(bob, depositAmount);

        vm.startPrank(alice);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(bob);
        _staking.stake{value: stakeAmount}(bob);

        uint256[] memory chipIds = array(uint256(1), uint256(2), uint256(3));
        expectEmit();
        emit Events.ChipsMerged(alice, bob, 4, chipIds);
        uint256 newChipId = _staking.mergeChips(chipIds);
        vm.stopPrank();

        // check new chip
        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(newChipId);
        assertEq(nodeAddr, bob);
        assertEq(tokens, stakeAmount * 3);
        assertEq(shares, stakeAmount * 3);
        // check old chips
        for (uint256 i = 1; i <= 3; i++) {
            (nodeAddr, tokens, shares) = _staking.getChipInfo(i);
            assertEq(nodeAddr, address(0));
            assertEq(shares, 0);
            assertEq(tokens, 0);

            vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, i));
            _chips.ownerOf(i);
        }
    }

    function testMergeChipsFail() public {
        // case 1: chipIds array length too short
        vm.expectRevert(abi.encodeWithSelector(ChipIdsArrayTooSmall.selector, 1));
        _staking.mergeChips(new uint256[](1));

        // case 2: chips are issued by the same node
        _createNode(bob);
        _createNode(carol);
        _deposit(bob, 10_000 ether);
        _deposit(carol, 10_000 ether);

        vm.startPrank(alice);
        _staking.stake{value: 500 ether}(bob);
        _staking.stake{value: 600 ether}(carol);

        vm.expectRevert(abi.encodeWithSelector(ChipNotValid.selector, 2, bob));
        _staking.mergeChips(array(uint256(1), uint256(2)));
        vm.stopPrank();
    }

    function testMergeChipsFailWithBurnedChips() public {
        // case 3: chips are not existed
        _createNode(bob);
        _deposit(bob, 10_000 ether);

        vm.startPrank(alice);
        _staking.stake{value: 500 ether}(bob);
        _staking.stake{value: 600 ether}(bob);
        vm.stopPrank();

        vm.startPrank(address(_staking));
        _chips.burn(1);
        _chips.burn(2);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, 1));
        vm.prank(alice);
        _staking.mergeChips(array(uint256(1), uint256(2)));
    }

    // solhint-disable-next-line function-max-lines
    function testDistributeRewardsSucceeds() public {
        uint256 depositAmount = 10_000 ether;
        uint256 stakeAmount = 20_000 ether;
        uint256 operationRewards = 200 ether;
        uint256 stakingRewards = 800 ether;

        // create node
        _createNode(alice);
        _createNode(bob);

        // deposit
        _deposit(alice, depositAmount);
        _deposit(bob, depositAmount);

        // stake
        uint256 tokenId1 = _staking.stake{value: stakeAmount}(alice);
        (,, uint256 shares1) = _staking.getChipInfo(tokenId1);

        uint256 tokenId2 = _staking.stake{value: stakeAmount}(bob);
        (,, uint256 shares2) = _staking.getChipInfo(tokenId2);

        // distribute rewards
        uint256 startTime = block.timestamp;
        skip(18 hours);
        uint256 endTime = block.timestamp;

        uint256[] memory taxAmounts = new uint256[](2);
        taxAmounts[0] = _getFullTax(operationRewards + stakingRewards, _defaultTaxRateBasisPoints);
        taxAmounts[1] = taxAmounts[0];

        expectEmit();
        emit Events.RewardDistributed(
            1,
            startTime,
            endTime,
            array(alice, bob),
            array(operationRewards, operationRewards),
            array(stakingRewards, stakingRewards),
            taxAmounts,
            array(1, 2)
        );
        vm.prank(address(_settlement));
        _staking.distributeRewards(
            [1, startTime, endTime],
            array(alice, bob),
            array(operationRewards, operationRewards),
            array(stakingRewards, stakingRewards),
            array(1, 2),
            0
        );

        // check status
        _checkDistribution(
            array(depositAmount, depositAmount),
            array(stakeAmount, stakeAmount),
            array(alice, bob),
            taxAmounts,
            array(operationRewards, operationRewards),
            array(stakingRewards, stakingRewards)
        );

        // chip price will goes up
        (, uint256 tokens, uint256 shares) = _staking.getChipInfo(1);
        assert(tokens > stakeAmount);
        assertEq(shares, shares1);

        (, tokens, shares) = _staking.getChipInfo(2);
        assert(tokens > stakeAmount);
        assertEq(shares, shares2);
    }

    function testDistributeRewardsFailInvalidArrayLength() public {
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _staking.distributeRewards(
            [uint256(1), uint256(1), uint256(2)],
            array(alice, bob),
            array(1),
            array(1, 1),
            array(1, 2),
            1 ether // public pool reward
        );
    }

    function testWithdraw2Treasury(uint256 amount) public {
        amount = bound(amount, 0, 10_000 ether);

        vm.deal(address(_staking), amount);

        _staking.withdraw2Treasury();
        assertEq(_cfg.treasury().balance, amount);
    }

    function testSetUpState() public view {
        assertEq(_staking.paused(), false);

        assertEq(_staking.getNodeCount(), 0);
        assertEq(_staking.chipsContract(), address(_chips));

        assertEq(_staking.isAlphaPhase(), _cfg.isAlphaPhase());

        assertEq(_staking.version(), "2.1.0");
        assertEq(_staking.TREASURY(), _cfg.treasury());
        assertEq(_staking.PAYMENT_PROCESSOR(), _cfg.paymentProcessor());
        assertEq(_staking.DEPOSIT_UNBONDING_PERIOD(), _cfg.depositUnbondingPeriod());
        assertEq(_staking.STAKE_UNBONDING_PERIOD(), _cfg.stakeUnbondingPeriod());

        // check public pool
        Node memory node = _staking.getPublicPool();
        assertEq(node.nodeId, 0);
        assertEq(node.account, address(0));
        assertEq(node.taxRateBasisPoints, 0);
        assertEq(node.publicGood, false);
        assertEq(node.alpha, _cfg.isAlphaPhase());
        assertEq(node.name, "");
        assertEq(node.description, "");
        assertEq(node.operationPoolTokens, 0);
        assertEq(node.stakingPoolTokens, 0);
        assertEq(node.totalShares, 0);
        assertEq(node.slashedStakingPoolTokens, 0);
        assertEq(node.slashedOperationPoolTokens, 0);
        assertEq(uint256(node.status), uint256(NodeStatus.None));

        // check an empty chip
        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(1);
        assertEq(nodeAddr, address(0));
        assertEq(tokens, 0);
        assertEq(shares, 0);

        // check constants
        assertLt(
            Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS + Const.SLASH_BURN_RATE_BASIS_POINTS,
            Const.DENOMINATOR
        );
        assertLt(Const.NODE_SLASH_RATE_BASIS_POINTS, Const.DENOMINATOR);
        assertLt(Const.USER_SLASH_RATE_BASIS_POINTS, Const.DENOMINATOR);
        assertLt(Const.MIN_TAX_RATE_BASIS_POINTS, Const.DENOMINATOR);
    }

    function testNodeAvatar() public view {
        string memory nodeAvatarURI = _staking.getNodeAvatar(bob);
        string memory base64prefix = "data:application/json;base64,";

        string memory decodedTokenURI =
            string(Base64.decode(LibString.slice(nodeAvatarURI, bytes(base64prefix).length)));
        assertEq(decodedTokenURI.readString(".name"), "Node Avatar");
        string memory base64Image = decodedTokenURI.readString(".image");

        string memory base64Imageprefix = "data:image/svg+xml;base64,";

        string memory decodedImageURI =
            string(Base64.decode(LibString.slice(base64Image, bytes(base64Imageprefix).length)));
        uint256 found1 = LibString.indexOf(decodedImageURI, "d{fill:#DEE5D9;}"); // head color white
        assertEq(found1 != LibString.NOT_FOUND, true);

        uint256 found2 = LibString.indexOf(decodedImageURI, "e{fill:#DEE5D9;}"); // head detail
            // color white
        assertEq(found2 != LibString.NOT_FOUND, true);
    }

    function testCalcTaxNoRewards(uint256 operationPool, uint256 rewards, uint256 stakingPool)
        public
        pure
    {
        // Case 1: Node receives no tax rewards (operation pool < 10000 ether)
        operationPool = bound(operationPool, 1, 10_000 ether - 1);
        rewards = bound(rewards, 1, 1_000_000 ether);
        stakingPool = bound(stakingPool, 1, 100_000 ether);

        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 totalTax, uint256 partialTax) =
            RewardsAndSlashingLib._getTax(rewards, taxRateBasisPoints, operationPool, stakingPool);

        uint256 expectedFullTax = _getFullTax(rewards, taxRateBasisPoints);
        assertEq(totalTax, expectedFullTax, "Total tax should equal full tax");
        assertEq(partialTax, 0, "Partial tax should be zero");
    }

    function testCalcTaxFullRewards(uint256 operationPool, uint256 stakeRatio) public pure {
        // Case 2: Node receives full tax rewards (operation pool >= 10000 ether)
        operationPool = bound(operationPool, 10_000 ether, 20_000 ether);
        stakeRatio = bound(stakeRatio, 1, 25);

        uint256 stakingPool = operationPool * stakeRatio;
        uint256 rewards = 10_000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 totalTax, uint256 partialTax) =
            RewardsAndSlashingLib._getTax(rewards, taxRateBasisPoints, operationPool, stakingPool);

        assertEq(totalTax, partialTax, "Total tax should equal partial tax for full rewards");

        uint256 expectedTax = _getFullTax(rewards, taxRateBasisPoints);
        assertEq(totalTax, expectedTax, "Total tax should equal expected full tax");
    }

    function testCalcTaxPartialRewards(uint256 stakingPool) public pure {
        // Case 3: Node receives partial tax rewards (operation pool >= MIN_DEPOSIT)
        uint256 operationPool = Const.MIN_DEPOSIT;
        stakingPool = bound(stakingPool, 25 * operationPool + 1, 100 * operationPool);

        uint256 rewards = 10_000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 totalTax, uint256 partialTax) =
            RewardsAndSlashingLib._getTax(rewards, taxRateBasisPoints, operationPool, stakingPool);

        uint256 expectedPartialTax = (totalTax * operationPool * 25) / stakingPool;
        assertApproxEqAbs(
            partialTax, expectedPartialTax, 12, "Partial tax should be less than upper bound"
        );

        // Additional check to ensure totalTax is greater than partialTax
        assertGt(totalTax, partialTax, "Total tax should be greater than partial tax");

        assert(totalTax / partialTax >= stakingPool / (operationPool * 25));
    }

    /// @dev stake and then request unstake
    function _testRequestUnstakeFromNode(address nodeAddr, bool isPublicGood) internal {
        uint256 amount = 10_000 ether;

        // stake
        vm.startPrank(bob);
        uint256 tokenId = isPublicGood
            ? _staking.stakeToPublicPool{value: amount}(nodeAddr)
            : _staking.stake{value: amount}(nodeAddr);

        // request unstake
        // chips should be burnt
        expectEmit();
        emit TestEvents.Transfer(bob, address(0), tokenId);
        expectEmit();
        emit Events.UnstakeRequested(bob, nodeAddr, 1, amount, array(tokenId));
        uint256 requestId = _staking.requestUnstake(nodeAddr, array(tokenId));
        vm.stopPrank();

        // check status
        UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount);

        // check node info
        Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.stakingPoolTokens, 0);
        assertEq(node.totalShares, 0);
    }

    function _testRequestUnstakeApprovedChipsFromNode(address nodeAddr, bool isPublicGood)
        internal
    {
        uint256 amount = 10_000 ether;

        // stake
        vm.startPrank(bob);
        uint256 tokenId = isPublicGood
            ? _staking.stakeToPublicPool{value: amount}(nodeAddr)
            : _staking.stake{value: amount}(nodeAddr);

        // approve chips for carol
        _chips.setApprovalForAll(carol, true);
        vm.stopPrank();

        // carol requests an unstake
        expectEmit();
        emit TestEvents.Transfer(bob, address(0), tokenId);
        expectEmit();
        emit Events.UnstakeRequested(bob, nodeAddr, 1, amount, array(tokenId));
        vm.prank(carol);
        uint256 requestId = _staking.requestUnstake(nodeAddr, array(tokenId));

        // check status
        UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount);

        // check node info
        Node memory node = isPublicGood ? _staking.getPublicPool() : _staking.getNode(nodeAddr);
        assertEq(node.stakingPoolTokens, 0);
        assertEq(node.totalShares, 0);
    }

    function _testRequestUnstakeApprovedChipFromNode(address nodeAddr, bool isPublicGood) internal {
        uint256 amount = 10_000 ether;

        // stake
        vm.prank(bob);
        uint256 tokenId = isPublicGood
            ? _staking.stakeToPublicPool{value: amount}(nodeAddr)
            : _staking.stake{value: amount}(nodeAddr);

        // approve only one chip
        vm.prank(bob);
        _chips.approve(carol, tokenId);

        uint256[] memory singleTokenId = array(tokenId);

        expectEmit();
        emit TestEvents.Transfer(bob, address(0), tokenId);
        expectEmit();
        emit Events.UnstakeRequested(bob, nodeAddr, 1, amount, singleTokenId);
        vm.prank(carol);
        uint256 requestId = _staking.requestUnstake(nodeAddr, singleTokenId);
        // check status
        _checkUnstakeOneChip(nodeAddr, requestId, amount, amount, isPublicGood);
    }

    function _unstakeAndCheckAmount(
        address sender,
        uint256 amount,
        uint256[] memory tokenIds,
        uint256[] memory taxAmounts,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards
    ) internal {
        vm.startPrank(sender);

        uint256 requestId = _staking.requestUnstake(alice, tokenIds);
        skip(22.5 days);

        uint256[] memory requestIds = array(requestId);

        uint256 allRewards = amount + operationRewards[0] + stakingRewards[0] - taxAmounts[0];

        uint256 balBefore = sender.balance;

        _staking.claimUnstake(requestIds);

        uint256 balAfter = sender.balance;

        assertEq(balAfter - balBefore, allRewards);

        vm.stopPrank();
    }

    function _checkUnstakeOneChip(
        address nodeAddr,
        uint256 requestId,
        uint256 stakedAmount,
        uint256 unstakedAmount,
        bool isPublicGood
    ) internal view {
        // check status
        UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, unstakedAmount);

        // check node info
        Node memory node = isPublicGood ? _staking.getPublicPool() : _staking.getNode(nodeAddr);

        assertEq(node.stakingPoolTokens, stakedAmount - unstakedAmount);
    }
}
