// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {stdJson} from "forge-std/StdJson.sol";
import {Base64} from "solady/utils/Base64.sol";
import {LibString} from "solady/utils/LibString.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {IERC721Errors} from "../src/interfaces/IERC721Errors.sol";
import {Const} from "../src/libraries/Const.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {
    NodeNotExists,
    NodeInExitStatus,
    TaxRateBasisPointsTooSmall,
    TaxRateBasisPointsTooLarge,
    PublicGoodNodeTaxNotZero,
    SlashStatusNotRecorded,
    SlashMoreThanOnce,
    SlashRecordNotExists,
    InvalidArrayLength,
    NodeExists,
    NodeIsPublicGood,
    CreateNodeToZeroAddress,
    ChipNotValid,
    ExcessWithdrawalAmount,
    WithdrawalAmountExceedsOperationPoolTokens,
    NodeDepositBelowMinimum,
    NodeNotInExitStatus,
    ClaimTimeNotReady,
    ClaimIdNotExists,
    ChipIdsLengthTooShort,
    SettlementPhase,
    EmptyChipIds,
    ChipsNotSameOwner,
    StakeAmountTooSmall,
    NodeNotPublicGood,
    StakeToPublicGoodNode,
    DepositForPublicGoodNode,
    WrongNodeStatus
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";
import {RewardsAndSlashingLib} from "../src/libraries/RewardsAndSlashingLib.sol";
import {Staking} from "../src/Staking.sol";

//import {console2 as console} from "forge-std/console2.sol";

contract StakingTest is CommonTest, IERC721Errors {
    using stdJson for string;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Paused(address account);
    event Unpaused(address account);

    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error EnforcedPause();
    error ExpectedPause();

    function setUp() public {
        _setUp();

        vm.deal(alice, _initialAmount);
        vm.deal(bob, _initialAmount);
        vm.deal(carol, _initialAmount);
        vm.deal(dave, _initialAmount);

        vm.deal(address(_settlement), 30000000 ether);
    }

    function testSetUpState() public {
        assertEq(_staking.paused(), false);

        assertEq(_staking.getNodeCount(), 0);
        assertEq(_staking.chipsContract(), address(_chips));

        assertEq(_staking.STAKE_UNBONDING_PERIOD(), stakeUnbondingPeriod);
        assertEq(_staking.DEPOSIT_UNBONDING_PERIOD(), depositUnbondingPeriod);
        assertEq(_staking.TREASURY(), treasury);

        vm.mockCall(
            address(_staking),
            abi.encodeWithSelector(Staking.getPublicPool.selector),
            abi.encode(
                DataTypes.Node({
                    nodeId: 0,
                    account: address(0),
                    taxRateBasisPoints: 0,
                    publicGood: false,
                    alpha: true,
                    name: "",
                    description: "",
                    operationPoolTokens: 0,
                    stakingPoolTokens: 0,
                    totalShares: 0,
                    slashStatus: false,
                    registerTime: 0,
                    offlineTime: 0,
                    exitingTime: 0,
                    status: DataTypes.NodeStatus.None
                })
            )
        );

        // check an empty chip
        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(1);
        assertEq(nodeAddr, address(0));
        assertEq(tokens, 0);
        assertEq(shares, 0);

        // check constants
        assertLt(Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS + Const.SLASH_BURN_RATE_BASIS_POINTS, Const.DENOMINATOR);
        assertLt(Const.NODE_SLASH_RATE_BASIS_POINTS, Const.DENOMINATOR);
        assertLt(Const.USER_SLASH_RATE_BASIS_POINTS, Const.DENOMINATOR);
        assertLt(Const.MIN_TAX_RATE_BASIS_POINTS, Const.DENOMINATOR);
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
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), PAUSE_ROLE));
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
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, address(this), PAUSE_ROLE));
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

        // case 8: set settlement phase
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.setSettlementPhase(true);

        // case 9: unstake
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.requestUnstake(alice, new uint256[](1));

        // case 10: claim unstake
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.claimUnstake(new uint256[](1));

        // case 11: distribute rewards
        vm.expectRevert(abi.encodeWithSelector(EnforcedPause.selector));
        _staking.distributeRewards(
            [uint256(1), uint256(1), uint256(2)],
            array(alice, bob),
            array(1, 1),
            array(1, 1),
            array(1, 2),
            1 ether // public pool reward
        );
    }

    function testCreateNode(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints >= Const.MIN_TAX_RATE_BASIS_POINTS && taxRateBasisPoints <= 10000);

        string memory name = "Alice";
        string memory description = "Alice's node";

        // case 1: create a node before alpha phase
        expectEmit();
        emit Events.NodeCreated(1, alice, name, description, taxRateBasisPoints, false, true);
        vm.prank(alice);
        _staking.createNode(name, description, taxRateBasisPoints, false);

        // check node info
        _checkNode(alice, 1, name, description, taxRateBasisPoints, 0, false, true);
        assertEq(_staking.getNodeCount(), 1);

        // case 2: create a node after alpha phase
        _disableAlphaPhase();
        expectEmit();
        emit Events.NodeCreated(2, bob, name, description, taxRateBasisPoints, false, false);
        vm.prank(bob);
        _staking.createNode(name, description, taxRateBasisPoints, false);
        _checkNode(bob, 2, name, description, taxRateBasisPoints, 0, false, false);
        assertEq(_staking.getNodeCount(), 2);
    }

    function testCreatePGNode() public {
        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(1, alice, name, description, 0, true, true);
        vm.prank(alice);
        _staking.createNode(name, description, 0, true);

        // check node info
        _checkNode(alice, 1, name, description, 0, 0, true, true);
        assertEq(_staking.getNodeCount(), 1);
    }

    function testCreatePGNodeFail() public {
        vm.expectRevert(abi.encodeWithSelector(PublicGoodNodeTaxNotZero.selector));
        _staking.createNode("Alice", "Alice's node", 1, true);
    }

    function testCreateNodeWithDeposit(uint64 taxRateBasisPoints, uint256 amount) public {
        vm.assume(taxRateBasisPoints >= Const.MIN_TAX_RATE_BASIS_POINTS && taxRateBasisPoints <= 10000);
        vm.assume(amount > 1 && amount < _initialAmount);

        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(1, alice, name, description, taxRateBasisPoints, false, true);
        expectEmit();
        emit Events.Deposited(alice, amount);

        vm.prank(alice);
        _staking.createNode{value: amount}(name, description, taxRateBasisPoints, false);

        // check node info
        _checkNode(alice, 1, name, description, taxRateBasisPoints, amount, false, true);
        assertEq(_staking.getNodeCount(), 1);

        // create node after alpha phase
        _disableAlphaPhase();
        expectEmit();
        emit Events.NodeCreated(2, bob, name, description, taxRateBasisPoints, false, false);
        vm.prank(bob);
        _staking.createNode(name, description, taxRateBasisPoints, false);
        _checkNode(bob, 2, name, description, taxRateBasisPoints, 0, false, false);
        assertEq(_staking.getNodeCount(), 2);
    }

    function testGetNodeCount() public {
        _createNode(alice);
        _createNode(bob);
        _createPublicGoodNode(carol);

        assertEq(_staking.getNodeCount(), 3);
    }

    function testGetNodes() public {
        _createNode(alice);
        _createNode(bob);
        _createPublicGoodNode(carol);
        _createNode(dave);

        // get nodes by addresses
        DataTypes.Node[] memory nodes2 = _staking.getNodes(array(alice, bob, carol, dave));
        assertEq(nodes2.length, 4);
        assertEq(nodes2[0].account, alice);
        assertEq(nodes2[1].account, bob);
        assertEq(nodes2[2].account, carol);
        assertEq(nodes2[3].account, dave);
        assertEq(nodes2[0].nodeId, 1);
        assertEq(nodes2[1].nodeId, 2);
        assertEq(nodes2[2].nodeId, 3);
        assertEq(nodes2[3].nodeId, 4);
    }

    function testUpdateNode() public {
        _createNode(alice);
        string memory newName = "New Alice";
        string memory newDescription = "New Alice's node";

        expectEmit();
        emit Events.NodeUpdated(alice, newName, newDescription);
        vm.prank(alice);
        _staking.updateNode(newName, newDescription);

        _checkNodeProfile(alice, newName, newDescription);
    }

    function testUpdateNodeFail() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.updateNode("New Alice", "New Alice's node");
    }

    function testCreateNodeFailWithMultipleNodes() public {
        _createNode(alice);

        vm.expectRevert(abi.encodeWithSelector(NodeExists.selector));
        _createNode(alice);
    }

    function testCreateNodeFailToZeroAddress() public {
        // create node to address(0) will fail
        vm.expectRevert(abi.encodeWithSelector(CreateNodeToZeroAddress.selector));
        _createNode(address(0));
    }

    function testCreateNodeFailWithLargeTaxRate(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints > 10000);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
        _staking.createNode("Alice", "Alice's node", taxRateBasisPoints, false);
    }

    function testCreateNodeFailWithSmallTaxRate(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints < 500);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooSmall.selector));
        _staking.createNode("Alice", "Alice's node", taxRateBasisPoints, false);
    }

    function testCreateNodeFailWithPublicGoodNodeDeposited() public {
        vm.expectRevert(abi.encodeWithSelector(DepositForPublicGoodNode.selector));
        _staking.createNode{value: 1}("Alice", "Alice's node", uint64(0), true);
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount > 10000 ether && amount < _initialAmount);

        _createNode(alice);

        expectEmit();
        emit Events.Deposited(alice, amount);
        vm.prank(alice);
        _staking.deposit{value: amount}();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.operationPoolTokens, amount);
    }

    function testDepositAfterExit() public {
        _disableAlphaPhase();

        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _staking.createNode("Name", "Description", _defaultTaxRateBasisPoints, false);
        _staking.deposit{value: 2 * amount}();

        _staking.requestExit();
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exiting));

        skip(Const.NODE_EXIT_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        _staking.requestWithdrawal(2 * amount);
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        // op pool < min deposit
        _staking.deposit{value: amount / 2}();
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        // op pool > min deposit
        _staking.deposit{value: amount / 2}();
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Registered));
        vm.stopPrank();
    }

    function testDepositFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.deposit{value: 1}();
    }

    function testDepositFailWithPublicGoodNodeDeposited() public {
        _staking.createNode("Alice", "Alice's node", uint64(0), true);

        vm.expectRevert(abi.encodeWithSelector(DepositForPublicGoodNode.selector));
        _staking.deposit{value: 1}();
    }

    function testRequestWithdrawalSucceeds() public {
        _disableAlphaPhase();

        uint256 depositAmount = 100000 ether;
        uint256 withdrawalAmount = depositAmount - Const.MIN_DEPOSIT;

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
        DataTypes.WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, withdrawalAmount);

        // check node info
        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.operationPoolTokens, depositAmount - withdrawalAmount);
    }

    function testRequestWithdrawalSucceedsWithExit() public {
        _disableAlphaPhase();

        uint256 amount = 100000 ether;

        vm.startPrank(alice);
        _staking.createNode{value: amount}("Alice", "Alice's node", uint64(1000), false);

        _staking.requestExit();
        skip(Const.NODE_EXIT_PERIOD);

        uint256 requestId = _staking.requestWithdrawal(amount);

        // check status
        DataTypes.WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, amount);

        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        // check node info
        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.operationPoolTokens, 0);
    }

    function testMultipleDepositAndRequestWithdrawal() public {
        _disableAlphaPhase();

        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _staking.createNode{value: amount}("Alice", "Alice's node", uint64(1000), false);

        _staking.deposit{value: amount}();

        _staking.requestExit();
        skip(Const.NODE_EXIT_PERIOD);

        uint256 requestId = _staking.requestWithdrawal(2 * amount);
        vm.stopPrank();

        // check status
        DataTypes.WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, 2 * amount);
    }

    function testRequestWithdrawalFailWithInsufficientTokens() public {
        _disableAlphaPhase();
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        // case 1: ExcessWithdrawalAmount
        vm.expectRevert(abi.encodeWithSelector(WithdrawalAmountExceedsOperationPoolTokens.selector));
        _staking.requestWithdrawal(amount + 1);

        // case 2: ExcessWithdrawalAmount
        _staking.requestExit();
        vm.expectRevert(abi.encodeWithSelector(ExcessWithdrawalAmount.selector));
        _staking.requestWithdrawal(amount);
        vm.stopPrank();
    }

    function testNodeStatus() public {
        _disableAlphaPhase();
        uint256 amount = 10000 ether;

        _createNode(alice);

        // none
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.None));

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        // registered
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Registered));

        // exiting
        _staking.requestExit();
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exiting));

        // exited
        skip(Const.NODE_EXIT_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        // registered
        _staking.reRegister();
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Registered));

        vm.stopPrank();
    }

    function testNodeExitedStatus() public {
        // case 1: Registered -> Exited
        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: 10000 ether}();

        skip(Const.NODE_INACTIVITY_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        // case 2: Offline -> Exited
        _createNode(bob);

        vm.prank(bob);
        _staking.deposit{value: 10000 ether}();

        vm.prank(address(_settlement));
        _staking.setNodeStatus(array(bob), array(DataTypes.NodeStatus.Offline));

        skip(Const.NODE_INACTIVITY_PERIOD);
        assertEq(uint256(_getNodeStatus(bob)), uint256(DataTypes.NodeStatus.Exited));
    }

    function testReRegister() public {
        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: 10000 ether}();

        _staking.requestExit();

        vm.expectEmit();
        emit Events.NodeReentryRequested(alice);
        _staking.reRegister();
        vm.stopPrank();
    }
    function testReRegisterFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.reRegister();

        _createNode(alice);
        vm.startPrank(alice);

        // case 2: node not in exit status
        vm.expectRevert(abi.encodeWithSelector(NodeNotInExitStatus.selector));
        _staking.reRegister();

        // case 3: node deposit is below minimum
        _staking.requestExit();

        vm.expectRevert(abi.encodeWithSelector(NodeDepositBelowMinimum.selector));
        _staking.reRegister();
        vm.stopPrank();
    }

    function testRequestWithdrawalFailWithNonExistentNode() public {
        _disableAlphaPhase();
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.requestWithdrawal(1 ether);
    }

    function testClaimWithdrawal() public {
        _disableAlphaPhase();

        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: amount}();
        _staking.requestExit();
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
        _disableAlphaPhase();
        _createNode(alice);

        uint256 depositAmount = 10000 ether;

        vm.startPrank(alice);
        _staking.deposit{value: depositAmount}();

        uint256 withdrawAmount = 10 ether;
        assertEq(depositAmount % withdrawAmount, 0);

        _staking.requestExit();
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

    function testAlphaPhase() public {
        vm.prank(alice);
        assertEq(_staking.isAlphaPhase(), true);

        _disableAlphaPhase();

        assertEq(_staking.isAlphaPhase(), false);
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

    function testSetTaxRate4Node(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints <= Const.DENOMINATOR && taxRateBasisPoints >= Const.MIN_TAX_RATE_BASIS_POINTS);

        _createNode(alice);

        vm.startPrank(alice);
        expectEmit();
        emit Events.NodeTaxRateBasisPointsSet(alice, taxRateBasisPoints);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);
        vm.stopPrank();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
    }

    function testSetTaxRate4PublicPool(uint64 expectedTaxRateBasisPoints) public {
        vm.assume(expectedTaxRateBasisPoints <= _denominator());

        vm.startPrank(address(_settlement));
        expectEmit();
        emit Events.PublicPoolTaxRateBasisPointsSet(expectedTaxRateBasisPoints);
        _staking.setTaxRateBasisPoints4PublicPool(expectedTaxRateBasisPoints);
        vm.stopPrank();

        uint64 realTaxRateBasisPoints = _staking.getPublicPool().taxRateBasisPoints;

        assertEq(realTaxRateBasisPoints, expectedTaxRateBasisPoints);
    }

    function testSetTaxRateTooSmallError(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooSmall.selector));
        vm.prank(oracleAccount);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);
    }

    function testSetTaxRateTooLargeError(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints > _denominator());

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
        vm.prank(alice);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
        vm.prank(address(_settlement));
        _staking.setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
    }

    function testSetTaxRateFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        vm.prank(dave);
        _staking.setTaxRateBasisPoints4Node(1000);
    }

    function testSetTaxRateFailWithPublicGoodNode() public {
        _createPublicGoodNode(dave);

        vm.expectRevert(abi.encodeWithSelector(NodeIsPublicGood.selector));
        vm.prank(dave);
        _staking.setTaxRateBasisPoints4Node(1000);
    }

    function testStake(uint256 amount) public {
        vm.assume(amount >= 500 && amount <= 1000000);
        amount *= 1 ether;

        _createNode(alice);

        expectEmit();
        emit TestEvents.Transfer(address(0), bob, 1);
        expectEmit();
        emit Events.Staked(bob, alice, amount, 1, 1);
        vm.prank(bob);
        uint256 tokenId = _staking.stake{value: amount}(alice);

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, amount);
        assertEq(node.totalShares, amount);

        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(tokenId);
        assertEq(nodeAddr, alice);
        assertEq(tokens, amount);
        assertEq(shares, amount);
    }

    function testStakeFailToNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
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
        _staking.stake{value: 10000 ether}(alice);
    }

    function testStakeFailWithNodeInExitStatus() public {
        _createNode(alice);

        vm.prank(alice);
        _staking.requestExit();

        vm.expectRevert(abi.encodeWithSelector(NodeInExitStatus.selector));
        _staking.stake{value: 10000 ether}(alice);
    }

    function testStakeToPublicPool(uint256 amount) public {
        vm.assume(amount >= 500 && amount < 10000);
        amount = amount * 1 ether;

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
        _staking.stakeToPublicPool{value: 10000 ether}(alice);
    }

    function testRequestUnstakeFromPublic() public {
        _createPublicGoodNode(alice);

        _disableAlphaPhase();
        // stake and then request unstake
        _testRequestUnstakeFromNode(alice, true);
    }

    function testRequestUnstake() public {
        _disableAlphaPhase();

        _createNode(alice);
        // stake and then request unstake
        _testRequestUnstakeFromNode(alice, false);
    }

    function testRequestUnstakeApprovedChip() public {
        _disableAlphaPhase();

        _createNode(alice);
        // stake and then request unstake
        _testRequestUnstakeApprovedChipFromNode(alice, false);
    }

    function testRequestUnstakeWithTransferChip() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(bob);
        _staking.stake{value: amount}(alice);
        _staking.stake{value: amount * 2}(alice);
        // bob transfers chips to carol
        _chips.transferFrom(bob, carol, 1);
        _chips.transferFrom(bob, carol, 2);
        vm.stopPrank();

        _disableAlphaPhase();

        // request unstake
        vm.prank(carol);
        uint256 requestId = _staking.requestUnstake(alice, array(uint256(1), uint256(2)));

        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, carol);
        assertEq(req.nodeAddr, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount * 3);
    }

    function testRequestUnstakeApprovedChipsFromPublicGoodNode() public {
        _createPublicGoodNode(alice);

        _disableAlphaPhase();
        _testRequestUnstakeApprovedChipsFromNode(alice, true);
    }

    function testRequestUnstakeApprovedChipFromPublicGoodNode() public {
        _createPublicGoodNode(alice);

        _disableAlphaPhase();
        _testRequestUnstakeApprovedChipFromNode(alice, true);
    }

    function testRequestUnstakeFailInEmptyChipsIds() public {
        _disableAlphaPhase();

        _createNode(alice);

        vm.expectRevert(abi.encodeWithSelector(EmptyChipIds.selector));
        _staking.requestUnstake(alice, new uint256[](0));
    }

    function testRequestUnstakeFailInChipsNotSameOwner() public {
        _disableAlphaPhase();

        _createNode(alice);

        vm.startPrank(bob);
        uint256 t1 = _staking.stake{value: 10000 ether}(alice);
        _chips.approve(carol, t1);

        vm.startPrank(carol);
        uint256 t2 = _staking.stake{value: 10000 ether}(alice);

        vm.expectRevert(abi.encodeWithSelector(ChipsNotSameOwner.selector));
        _staking.requestUnstake(alice, array(t1, t2));
        vm.stopPrank();
    }

    function testRequestUnstakeFailInSettlementPhase() public {
        _disableAlphaPhase();

        _createNode(alice);

        _staking.stake{value: 5000 ether}(alice);

        vm.prank(address(_settlement));
        _staking.setSettlementPhase(true);

        vm.expectRevert(abi.encodeWithSelector(SettlementPhase.selector));
        _staking.requestUnstake(alice, array(1));
    }

    function testRequestUnstakeFailWithBurnedChip() public {
        _disableAlphaPhase();

        uint256 amount = 10000 ether;

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
        vm.assume(amount > 500 && amount < 10000);
        amount *= 1 ether;

        _disableAlphaPhase();

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

        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, address(0));
        assertEq(req.nodeAddr, address(0));
        assertEq(req.timestamp, 0);
        assertEq(req.unstakeAmount, 0);
    }

    function testClaimUnstakeFail() public {
        _createNode(alice);
        _disableAlphaPhase();

        vm.startPrank(bob);

        // case 1: claim id not exists
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, uint256(1)));
        _staking.claimUnstake(array(uint256(1)));

        uint256 tokenId = _staking.stake{value: 10000 ether}(alice);
        uint256 requestId = _staking.requestUnstake(alice, array(tokenId));

        // case 2: claim time not ready
        vm.expectRevert(abi.encodeWithSelector(ClaimTimeNotReady.selector));
        _staking.claimUnstake(array(requestId));

        vm.stopPrank();
    }

    function testRequestUnstakeWithMergedChips() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 20000 ether;

        _createNode(bob);
        _deposit(bob, depositAmount);
        _disableAlphaPhase();

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

        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, address(0));
        assertEq(req.nodeAddr, address(0));
        assertEq(req.timestamp, 0);
        assertEq(req.unstakeAmount, 0);

        // check node
        DataTypes.Node memory node = _staking.getNode(bob);
        assertEq(node.stakingPoolTokens, 0);
    }

    function testMergeChips() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 20000 ether;

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
        vm.expectRevert(abi.encodeWithSelector(ChipIdsLengthTooShort.selector));
        _staking.mergeChips(new uint256[](0));

        // case 2: chips are issued by the same node
        _createNode(bob);
        _createNode(carol);
        _deposit(bob, 10000 ether);
        _deposit(carol, 10000 ether);

        vm.startPrank(alice);
        _staking.stake{value: 500 ether}(bob);
        _staking.stake{value: 600 ether}(carol);

        vm.expectRevert(abi.encodeWithSelector(ChipNotValid.selector, 2, bob));
        _staking.mergeChips(array(uint256(1), uint256(2)));
        vm.stopPrank();
    }

    // solhint-disable-next-line function-max-lines
    function testDistributeRewardsSucceeds() public {
        uint256 depositAmount = 10000 ether;
        uint256 stakeAmount = 20000 ether;
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
        (, , uint256 shares1) = _staking.getChipInfo(tokenId1);

        uint256 tokenId2 = _staking.stake{value: stakeAmount}(bob);
        (, , uint256 shares2) = _staking.getChipInfo(tokenId2);

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
        vm.assume(amount > 0);

        vm.deal(address(_staking), amount);

        _staking.withdraw2Treasury();
        assertEq(treasury.balance, amount);
    }

    // Test errors: InvalidArrayLength, NodeNotExists, SlashPublicGoodNode, SlashMoreThanOnce
    function testRecordSlashingFail() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        address[] memory reporters = array(carol, dave);

        DataTypes.Slashing[] memory slashings = _createSlashings(array(alice, bob), array(123, 123));

        address[] memory wrongReporters = array(carol);

        // InvalidArrayLength
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _recordSlashingWithReasons(slashings, wrongReporters);

        // NodeNotExists
        slashings[1].nodeAddr = address(0x0); // alice, 0x0
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        vm.prank(address(_settlement));
        _recordSlashingWithReasons(slashings, reporters);

        // SlashMoreThanOnce
        slashings[1].nodeAddr = alice; // alice, alice
        vm.expectRevert(abi.encodeWithSelector(SlashMoreThanOnce.selector, alice, 123));
        vm.prank(address(_settlement));
        _recordSlashingWithReasons(slashings, reporters);

        // SlashPublicGoodNode
        _createPublicGoodNode(carol);
        DataTypes.Slashing memory slashCarol = DataTypes.Slashing(carol, 123);
        DataTypes.Slashing[] memory slashingPGs = new DataTypes.Slashing[](1);
        slashingPGs[0] = slashCarol;
        address[] memory reporters2 = array(dave);

        vm.prank(address(_settlement));
        _recordSlashingWithReasons(slashingPGs, reporters2);
    }

    // Test:
    // 1. event emitted as expected
    // 2. staking and operation pool tokens decreased as expected
    // 3. record info updated as expected
    function testRecordSlashing() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) /
            _denominator();

        address[] memory nodeAddrs = array(alice, bob);
        address[] memory reporters = array(carol, dave);
        uint256[] memory epochIds = array(123, 123);

        DataTypes.Slashing[] memory slashings = _createSlashings(nodeAddrs, epochIds);

        // 1. events emitted as expected
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            expectEmit();
            emit Events.SlashRecorded(
                nodeAddrs[i],
                epochIds[i],
                reporters[i],
                expectedSlashedTokensOnOperationPool,
                expectedSlashedTokensOnStakingPool
            );
        }
        vm.prank(address(_settlement));
        _recordSlashingWithReasons(slashings, reporters);

        DataTypes.SlashRecord[] memory records = _staking.getSlashingRecords(slashings);
        // 2. records info updated correctly
        for (uint256 i = 0; i < records.length; i++) {
            assertEq(records[i].reporter, reporters[i]);
            assertEq(records[i].amountForOperationPool, expectedSlashedTokensOnOperationPool);
            assertEq(records[i].amountForStakingPool, expectedSlashedTokensOnStakingPool);
            assertTrue(records[i].status == DataTypes.SlashStatus.Recorded);
        }

        // 3. check staking pool and operation tokens
        DataTypes.Node memory aliceNode = _staking.getNode(alice);
        DataTypes.Node memory bobNode = _staking.getNode(bob);
        assertEq(aliceNode.stakingPoolTokens, stakedTokens - expectedSlashedTokensOnStakingPool);
        assertEq(aliceNode.operationPoolTokens, depositedTokens - expectedSlashedTokensOnOperationPool);
        assertEq(bobNode.stakingPoolTokens, stakedTokens - expectedSlashedTokensOnStakingPool);
        assertEq(bobNode.operationPoolTokens, depositedTokens - expectedSlashedTokensOnOperationPool);

        // 4. slash status updated correctly
        assertEq(aliceNode.slashStatus, true);
        assertEq(bobNode.slashStatus, true);
    }

    // Test errors: SlashRecordNotExists, SlashStatusNotRecorded
    function testCommitSlashingFail() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        address[] memory nodeAddrs = array(alice, bob);
        uint256[] memory epochIds = array(123, 123);
        DataTypes.Slashing[] memory slashings = _createSlashings(nodeAddrs, epochIds);
        DataTypes.Slashing[] memory slashingAlices = _createSlashings(array(alice), array(123));
        DataTypes.Slashing[] memory slashingBobs = _createSlashings(array(bob), array(123));

        address[] memory reporters = array(address(0xabc), address(0xdef));

        vm.startPrank(address(_settlement));

        // 1. cannot commit a non-exsistent one
        DataTypes.Slashing[] memory slashingNulls = _createSlashings(array(carol), array(789));
        vm.expectRevert(abi.encodeWithSelector(SlashRecordNotExists.selector, carol, 789));
        _staking.commitSlashing(slashingNulls);

        _recordSlashingWithReasons(slashings, reporters);

        // 2.1 cannot commit a revoked one
        _staking.revokeSlashing(slashingAlices);

        vm.expectRevert(abi.encodeWithSelector(SlashStatusNotRecorded.selector, alice, 123));
        _staking.commitSlashing(slashingAlices);

        // 2.2 cannot commit a committed one
        _staking.commitSlashing(slashingBobs);

        vm.expectRevert(abi.encodeWithSelector(SlashStatusNotRecorded.selector, bob, 123));
        _staking.commitSlashing(slashingBobs);

        vm.stopPrank();
    }

    // Test:
    // 1. Events emitted as expected
    // 2. Slashed tokens distributed as expected
    // 3. Slashing info updated as expected
    // solhint-disable-next-line function-max-lines
    function testCommitSlashing() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) /
            _denominator();

        _setUpNodes(depositedTokens, stakedTokens);
        uint256 treasuryAmount = _getTreasuryAmount();

        address[] memory nodeAddrs = array(alice, bob);
        uint256[] memory epochIds = array(123, 123);

        address[] memory reporters = array(address(0xabc), address(0x0));

        DataTypes.Slashing[] memory slashings = _createSlashings(nodeAddrs, epochIds);

        uint256 stakingPoolTokens = _staking.getNode(alice).stakingPoolTokens;
        uint256 operationPoolTokens = _staking.getNode(alice).operationPoolTokens;

        // 1. record slashing
        vm.prank(address(_settlement));
        _recordSlashingWithReasons(slashings, reporters);

        // 1.1 check: treasury amount will not change after record slashing
        assertEq(treasuryAmount, 0);

        // 2. commit slashing and events emitted as expected
        expectEmit();
        emit Events.SlashCommitted(alice, 123);
        emit Events.SlashCommitted(bob, 123);
        vm.prank(address(_settlement));
        _staking.commitSlashing(slashings);

        // 3. check: slashed tokens distributed as expected
        // 3.1 reporters balance correct
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            uint256 value = ((expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) *
                Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS) / _denominator();
            if (reporters[i] == address(0x0)) {
                assertEq(paymentProcessor.balance, value);
            } else {
                assertEq(reporters[i].balance, value);
            }
        }

        // 3.2 Treasury amount correct
        uint256 treasuryAmountAfterSlashing = _getTreasuryAmount();
        uint256 expectedTreasuryAmount = 2 *
            (expectedSlashedTokensOnOperationPool +
                expectedSlashedTokensOnStakingPool -
                (((expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) *
                    (Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS + Const.SLASH_BURN_RATE_BASIS_POINTS)) /
                    _denominator()));

        assertEq(treasuryAmountAfterSlashing, expectedTreasuryAmount);
        // 3.3 Node pool tokens correct
        DataTypes.Node memory aliceNode = _staking.getNode(alice);
        assertEq(aliceNode.stakingPoolTokens, stakingPoolTokens - expectedSlashedTokensOnStakingPool);
        assertEq(aliceNode.operationPoolTokens, operationPoolTokens - expectedSlashedTokensOnOperationPool);

        DataTypes.SlashRecord[] memory records = _staking.getSlashingRecords(slashings);
        // 4. Record status updated correctly
        for (uint256 i = 0; i < records.length; i++) {
            assertTrue(records[i].status == DataTypes.SlashStatus.Committed);
        }
        assertEq(aliceNode.slashStatus, false);
    }

    // Test Errors: SlashRecordNotExists, SlashStatusNotRecorded
    function testRevokeSlashingFail() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        address[] memory nodeAddrs = array(alice, bob);
        uint256[] memory epochIds = array(123, 123);

        address[] memory reporters = array(address(0xabc), address(0xdef));

        _setUpNodes(depositedTokens, stakedTokens);
        vm.startPrank(address(_settlement));

        // 1. Cannot revoke a non-exsistent one
        vm.expectRevert(abi.encodeWithSelector(SlashRecordNotExists.selector, alice, 123));
        DataTypes.Slashing[] memory slashingAlices = _createSlashings(array(alice), array(123));
        _staking.revokeSlashing(slashingAlices);

        _recordSlashingWithReasons(_createSlashings(nodeAddrs, epochIds), reporters);

        // 2. Cannot revoke a revoked one
        _staking.revokeSlashing(slashingAlices);

        vm.expectRevert(abi.encodeWithSelector(SlashStatusNotRecorded.selector, alice, 123));
        _staking.revokeSlashing(slashingAlices);

        // 3. Cannot revoke a committed one
        DataTypes.Slashing[] memory slashingBobs = _createSlashings(array(bob), array(123));

        _staking.commitSlashing(slashingBobs);

        vm.expectRevert(abi.encodeWithSelector(SlashStatusNotRecorded.selector, bob, 123));
        _staking.revokeSlashing(slashingBobs);

        vm.stopPrank();
    }

    // Test:
    // 1. Events emitted as expected
    // 2. Slashed tokens returned as expected
    // 3. Slashing info updated as expected
    function testRevokeSlashing() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;
        _setUpNodes(depositedTokens, stakedTokens);

        // 1. record slashing
        vm.startPrank(address(_settlement));
        DataTypes.Slashing[] memory slashings = _createSlashings(array(alice, bob), array(123, 123));
        _recordSlashingWithReasons(slashings, array(carol, dave));

        // 2. revoke slashing and events emitted as expected
        expectEmit();
        emit Events.SlashRevoked(alice, 123);
        emit Events.SlashRevoked(bob, 123);
        _staking.revokeSlashing(slashings);
        vm.stopPrank();

        // 3. check: slashed tokens returned as expected
        // 3.1 staking pool and operation pool tokens correct
        DataTypes.Node memory aliceNode = _staking.getNode(alice);
        DataTypes.Node memory bobNode = _staking.getNode(bob);
        assertEq(aliceNode.stakingPoolTokens, stakedTokens);
        assertEq(aliceNode.operationPoolTokens, depositedTokens);
        assertEq(bobNode.stakingPoolTokens, stakedTokens);
        assertEq(bobNode.operationPoolTokens, depositedTokens);

        // 3.2 reporters balance correct
        for (uint256 i = 0; i < 2; i++) {
            assertEq(carol.balance, _initialAmount);
            assertEq(dave.balance, _initialAmount);
        }

        // 3.3 treasury balance correct
        uint256 amount = _getTreasuryAmount();
        assertEq(amount, 0);

        // 4. slash status updated correctly
        assertEq(aliceNode.slashStatus, false);
        assertEq(bobNode.slashStatus, false);
    }

    // Test multiple slashings
    function testRecordSlashingMulti() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        address[] memory reporters = array(carol, dave);
        uint256[] memory epochIds = array(123, 123);

        DataTypes.Slashing[] memory slashings = _createSlashings(array(alice, bob), epochIds);
        DataTypes.Slashing[] memory slashingAlices = _createSlashings(array(alice), array(123));

        // 1. record slashing alice and bob
        vm.startPrank(address(_settlement));
        _recordSlashingWithReasons(slashings, reporters);
        // 2. revoke slashing alice
        _staking.revokeSlashing(slashingAlices);
        // 3. record slashing alice again
        _recordSlashingWithReasons(slashingAlices, array(dave));
        // 4. commit all slashing: alice and bob
        _staking.commitSlashing(slashings);

        // 5. Check: treasury amount correct
        uint256 treasuryAmount = _getTreasuryAmount();

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * Const.NODE_SLASH_RATE_BASIS_POINTS) /
            _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * Const.USER_SLASH_RATE_BASIS_POINTS) /
            _denominator();

        uint256 expectedTreasuryAmount = 2 *
            (expectedSlashedTokensOnOperationPool +
                expectedSlashedTokensOnStakingPool -
                (((expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) *
                    (Const.SLASH_REPORTER_BONUS_RATE_BASIS_POINTS + Const.SLASH_BURN_RATE_BASIS_POINTS)) /
                    _denominator()));
        assertEq(treasuryAmount, expectedTreasuryAmount);

        // 6. record slashing alice twice will reverted
        address[] memory sameNodeAddrs = array(alice, alice);
        uint256[] memory diffEpochIds = array(124, 125);

        DataTypes.Slashing[] memory slashings2 = _createSlashings(sameNodeAddrs, diffEpochIds);
        vm.expectRevert(abi.encodeWithSelector(SlashMoreThanOnce.selector, alice, 125));
        _recordSlashingWithReasons(slashings2, reporters);
    }

    function testRequestExitSucceeds() public {
        vm.startPrank(alice);
        _staking.createNode{value: 10000 ether}("Alice", "Alice's node", uint64(1000), false);

        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Registered));

        expectEmit();
        emit Events.NodeExitRequested(alice);
        _staking.requestExit();

        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exiting));

        skip(Const.NODE_EXIT_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(DataTypes.NodeStatus.Exited));

        vm.stopPrank();
    }

    function testRequestExitFail() public {
        // case 1: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.requestExit();

        // case 2: NodeInExitStatus
        vm.startPrank(alice);
        _staking.createNode{value: 10000 ether}("Alice", "Alice's node", uint64(1000), false);
        _staking.requestExit();

        vm.expectRevert(abi.encodeWithSelector(NodeInExitStatus.selector));
        _staking.requestExit();

        skip(3 * 18 hours);
        vm.expectRevert(abi.encodeWithSelector(NodeInExitStatus.selector));
        _staking.requestExit();

        vm.stopPrank();
    }

    function testDemoteNodes() public {
        _createNode(alice);
        _createPublicGoodNode(bob);
        _createNode(carol);

        address[] memory nodeAddrs = array(alice, bob, carol);

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            expectEmit();
            emit Events.NodeDemoted(1, nodeAddrs[i], 1);
        }
        vm.prank(address(_settlement));
        _staking.demoteNodes(1, nodeAddrs);

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            assertEq(_staking.getDemotionCount(1, nodeAddrs[i]), 1);
        }
    }

    function testSetNodesStatus() public {
        _createNode(alice);
        _createPublicGoodNode(bob);
        _createNode(carol);

        address[] memory nodeAddrs = array(alice, bob, carol);
        DataTypes.NodeStatus[] memory status = new DataTypes.NodeStatus[](3);
        status[0] = DataTypes.NodeStatus.Online;
        status[1] = DataTypes.NodeStatus.Offline;
        status[2] = DataTypes.NodeStatus.Initializing;

        expectEmit();
        emit Events.NodeStatusSet(nodeAddrs, status);
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, status);

        // check status
        DataTypes.Node[] memory nodes = _staking.getNodes(nodeAddrs);
        assertEq(uint256(nodes[0].status), uint256(DataTypes.NodeStatus.Online));
        assertEq(uint256(nodes[1].status), uint256(DataTypes.NodeStatus.Offline));
        assertEq(uint256(nodes[2].status), uint256(DataTypes.NodeStatus.Initializing));
    }

    function testSetNodesStatusFail() public {
        _createNode(alice);
        _createPublicGoodNode(bob);

        address[] memory nodeAddrs = array(alice, bob);

        // WrongNodeStatus
        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, 0));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, array(DataTypes.NodeStatus.None, DataTypes.NodeStatus.Offline));

        // WrongNodeStatus
        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, 1));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, array(DataTypes.NodeStatus.Registered, DataTypes.NodeStatus.Offline));

        // WrongNodeStatus
        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, 5));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, array(DataTypes.NodeStatus.Slashing, DataTypes.NodeStatus.Offline));

        // WrongNodeStatus
        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, 6));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, array(DataTypes.NodeStatus.Slashed, DataTypes.NodeStatus.Offline));

        // WrongNodeStatus
        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, 7));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, array(DataTypes.NodeStatus.Exiting, DataTypes.NodeStatus.Offline));

        // WrongNodeStatus
        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, 8));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(nodeAddrs, array(DataTypes.NodeStatus.Exited, DataTypes.NodeStatus.Offline));
    }

    function testNodeAvatar() public view {
        string memory nodeAvatarURI = _staking.getNodeAvatar(bob);
        string memory base64prefix = "data:application/json;base64,";

        string memory decodedTokenURI = string(
            Base64.decode(LibString.slice(nodeAvatarURI, bytes(base64prefix).length))
        );
        assertEq(decodedTokenURI.readString(".name"), "Node Avatar");
        string memory base64Image = decodedTokenURI.readString(".image");

        string memory base64Imageprefix = "data:image/svg+xml;base64,";

        string memory decodedImageURI = string(
            Base64.decode(LibString.slice(base64Image, bytes(base64Imageprefix).length))
        );
        uint256 found1 = LibString.indexOf(decodedImageURI, "d{fill:#DEE5D9;}"); // head color white
        assertEq(found1 != LibString.NOT_FOUND, true);

        uint256 found2 = LibString.indexOf(decodedImageURI, "e{fill:#DEE5D9;}"); // head detail color white
        assertEq(found2 != LibString.NOT_FOUND, true);
    }

    function testCalcTax1(uint256 operationPool) public pure {
        // case 1: receives no tax rewards
        vm.assume(operationPool < 10000 ether);

        uint256 rewards = 10000 ether;
        uint256 stakingPool = 1000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 tax1, uint256 partialTax1) = RewardsAndSlashingLib._getTax(
            rewards,
            taxRateBasisPoints,
            operationPool,
            stakingPool
        );

        assertEq(tax1, _getFullTax(rewards, taxRateBasisPoints));
        assertEq(partialTax1, 0);
    }

    function testCalcTax2() public pure {
        // case 2: receives full tax rewards
        uint256 operationPool = Const.MIN_DEPOSIT;
        uint256 stakeRatio;
        vm.assume(stakeRatio < 25);

        uint256 stakingPool = operationPool * stakeRatio;

        uint256 rewards = 10000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 tax, uint256 partialTax) = RewardsAndSlashingLib._getTax(
            rewards,
            taxRateBasisPoints,
            operationPool,
            stakingPool
        );

        assertEq(tax, partialTax);
    }

    function testCalcTax3(uint256 stakingPool) public pure {
        // case 2: receives partial tax rewards
        uint256 operationPool = Const.MIN_DEPOSIT;

        vm.assume(stakingPool > 25 * operationPool && Const.STAKE_RATIO < 100 * operationPool);

        uint256 rewards = 10000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 tax, uint256 partialTax) = RewardsAndSlashingLib._getTax(
            rewards,
            taxRateBasisPoints,
            operationPool,
            stakingPool
        );

        // partialTax has precision 1
        assert(
            tax * operationPool * 25 >= partialTax * stakingPool &&
                tax * operationPool * 25 < (partialTax + 1) * stakingPool
        );
        // assert(tax / partialTax >= stakingPool / (operationPool * 25));
    }

    /// @dev stake and then request unstake
    function _testRequestUnstakeFromNode(address nodeAddr, bool isPublicGood) internal {
        uint256 amount = 10000 ether;

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
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount);

        // check node info
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.stakingPoolTokens, 0);
        assertEq(node.totalShares, 0);
    }

    function _testRequestUnstakeApprovedChipsFromNode(address nodeAddr, bool isPublicGood) internal {
        uint256 amount = 10000 ether;

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
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount);

        // check node info
        DataTypes.Node memory node = isPublicGood ? _staking.getPublicPool() : _staking.getNode(nodeAddr);
        assertEq(node.stakingPoolTokens, 0);
        assertEq(node.totalShares, 0);
    }

    function _testRequestUnstakeApprovedChipFromNode(address nodeAddr, bool isPublicGood) internal {
        uint256 amount = 10000 ether;

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

    function _setUpNodes(uint256 depositedTokens, uint256 stakedTokens) internal {
        _createNode(alice);
        _createNode(bob);

        _deposit(alice, depositedTokens);
        _deposit(bob, depositedTokens);

        _staking.stake{value: stakedTokens}(alice);
        _staking.stake{value: stakedTokens}(bob);
    }

    function _recordSlashingWithReasons(DataTypes.Slashing[] memory slashings, address[] memory reporters) internal {
        string[] memory reasons = new string[](slashings.length);
        for (uint256 i = 0; i < slashings.length; i++) {
            reasons[i] = "";
        }

        _staking.recordSlashing(slashings, reporters, reasons);
    }

    function _checkUnstakeOneChip(
        address nodeAddr,
        uint256 requestId,
        uint256 stakedAmount,
        uint256 unstakedAmount,
        bool isPublicGood
    ) internal view {
        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, unstakedAmount);

        // check node info
        DataTypes.Node memory node = isPublicGood ? _staking.getPublicPool() : _staking.getNode(nodeAddr);

        assertEq(node.stakingPoolTokens, stakedAmount - unstakedAmount);
    }

    function _checkNodeProfile(address nodeAddr, string memory name, string memory description) internal view {
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
    }

    function _checkNode(
        address nodeAddr,
        uint256 nodeId,
        string memory name,
        string memory description,
        uint64 taxRateBasisPoints,
        uint256 operationPoolTokens,
        bool publicGood,
        bool alpha
    ) internal view {
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        _checkNodeProfile(nodeAddr, name, description);
        assertEq(node.nodeId, nodeId);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.publicGood, publicGood);
        assertEq(node.alpha, alpha);
    }

    function _getNodeStatus(address nodeAddr) internal view returns (DataTypes.NodeStatus status) {
        status = _staking.getNode(nodeAddr).status;
    }

    function _createSlashings(
        address[] memory nodeAddrs,
        uint256[] memory epochIds
    ) internal pure returns (DataTypes.Slashing[] memory) {
        DataTypes.Slashing[] memory slashings = new DataTypes.Slashing[](nodeAddrs.length);

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            slashings[i] = DataTypes.Slashing(nodeAddrs[i], epochIds[i]);
        }

        return slashings;
    }
}
