// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {Events} from "../src/libraries/Events.sol";
import {IERC721Errors} from "../src/interfaces/IERC721Errors.sol";
import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";
import {stdJson} from "forge-std/StdJson.sol";

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

        vm.deal(address(_settlement), 30000000 ether);
    }

    function testSetUpState() public {
        assertEq(_staking.paused(), false);

        assertEq(_staking.getNodeCount(), 0);
        assertEq(_staking.MIN_DEPOSIT(), minDeposit);
        assertEq(_staking.chipsContract(), address(_chips));

        assertEq(_staking.STAKE_UNBONDING_PERIOD(), stakeUnbondingPeriod);
        assertEq(_staking.DEPOSIT_UNBONDING_PERIOD(), depositUnbondingPeriod);
        assertEq(_staking.NODE_SLASH_RATE_BASIS_POINTS(), nodeSlashRateBasisPoints);
        assertEq(_staking.USER_SLASH_RATE_BASIS_POINTS(), userSlashRateBasisPoints);
        assertEq(_staking.STAKE_RATIO(), stakeRatio);
        assertEq(_staking.TREASURY(), treasury);
        assertEq(_staking.SHARES_PER_CHIP(), 500 ether);
        assertEq(_staking.MIN_DEPOSIT(), minDeposit);
        assertEq(_staking.MIN_TAX_RATE_BASIS_POINTS(), minTaxRateBasisPoints);

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
                    slashedTokens: 0
                })
            )
        );
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
        vm.assume(taxRateBasisPoints >= minTaxRateBasisPoints && taxRateBasisPoints <= 10000);

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

    function testNodeAvatar() public {
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
        uint256 found1 = LibString.indexOf(decodedImageURI, "b{fill:#DEE5D9;}"); // head color white
        assertEq(found1 != LibString.NOT_FOUND, true);

        uint256 found2 = LibString.indexOf(decodedImageURI, "h{fill:#DEE5D9;}"); // head detail color white
        assertEq(found2 != LibString.NOT_FOUND, true);
    }

    function testCreateNodeWithDeposit(uint64 taxRateBasisPoints, uint256 amount) public {
        vm.assume(taxRateBasisPoints >= minTaxRateBasisPoints && taxRateBasisPoints <= 10000);
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

        // get nodes with pagination
        DataTypes.Node[] memory nodes = _staking.getNodesWithPagination(0, 4);
        assertEq(nodes.length, 4);
        assertEq(nodes[0].account, alice);
        assertEq(nodes[1].account, bob);
        assertEq(nodes[2].account, carol);
        assertEq(nodes[3].account, dave);
        assertEq(nodes[0].nodeId, 1);
        assertEq(nodes[1].nodeId, 2);
        assertEq(nodes[2].nodeId, 3);
        assertEq(nodes[3].nodeId, 4);

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

    function testUpdateToPublicGood() public {
        _createNode(alice);
        uint256 dpAmount = 5000 ether;
        uint256 stAmount = 60000 ether;

        vm.prank(alice);
        _staking.deposit{value: dpAmount}();

        vm.prank(bob);
        _staking.stake{value: stAmount}(alice);

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.publicGood, false);
        assertEq(node.operationPoolTokens, dpAmount);
        assertEq(node.stakingPoolTokens, stAmount);

        expectEmit();
        emit Events.WithdrawRequested(alice, dpAmount, 1);
        emit Events.NodeUpdated2PublicGood(alice);
        vm.prank(alice);
        _staking.updateToPublicGood();

        // check status
        DataTypes.Node memory updatedNode = _staking.getNode(alice);
        DataTypes.Node memory publicPool = _staking.getPublicPool();
        (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens) = _staking.getPoolInfo();

        assertEq(updatedNode.publicGood, true);
        assertEq(updatedNode.operationPoolTokens, 0);
        assertEq(updatedNode.taxRateBasisPoints, 0);

        assertEq(updatedNode.stakingPoolTokens, 0);
        assertEq(publicPool.stakingPoolTokens, stAmount);

        assertEq(totalOperationPoolTokens, 0);
        assertEq(totalStakingPoolTokens, stAmount);

        DataTypes.WithdrawalRequest memory pendingWithdrawl = _staking.getPendingWithdrawal(1);
        assertEq(pendingWithdrawl.owner, alice);
        assertEq(pendingWithdrawl.amount, dpAmount);
        assertEq(pendingWithdrawl.timestamp, block.timestamp);
    }

    function testUpdateToPublicGoodFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.updateToPublicGood();

        // case 2: node is already a public good node
        _createPublicGoodNode(alice);
        vm.expectRevert(abi.encodeWithSelector(NodeAlreadyPublicGood.selector, alice));
        vm.prank(alice);
        _staking.updateToPublicGood();
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
        vm.expectRevert(abi.encodeWithSelector(PublicGoodNodeNotDeposited.selector));
        _staking.createNode{value: 1}("Alice", "Alice's node", uint64(100), true);
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

    function testDepositFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.deposit{value: 1}();
    }

    function testDepositFailWithZeroAmount() public {
        vm.expectRevert(abi.encodeWithSelector(InsufficientValue.selector));
        _staking.deposit{value: 0}();
    }

    function testRequestWithdrawal() public {
        _disableAlphaPhase();

        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _staking.createNode{value: amount}("Alice", "Alice's node", uint64(1000), false);

        uint256 requestId = _staking.requestWithdrawal(amount);

        // requestWithdrawl again will fail
        vm.expectRevert(abi.encodeWithSelector(ExcessWithdrawalAmount.selector));
        _staking.requestWithdrawal(amount);
        vm.stopPrank();

        // check status
        DataTypes.WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, amount);

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

        vm.expectRevert(abi.encodeWithSelector(ExcessWithdrawalAmount.selector));
        _staking.requestWithdrawal(amount + 1);
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

        uint256 requestId = _staking.requestWithdrawal(amount);

        uint256[] memory requestIds = array(requestId);

        vm.expectRevert(abi.encodeWithSelector(ClaimTimeNotReady.selector));
        _staking.claimWithdrawal(requestIds);

        skip(depositUnbondingPeriod);

        expectEmit();
        emit Events.WithdrawalClaimed(requestId);
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
        vm.assume(taxRateBasisPoints <= _denominator() && taxRateBasisPoints >= minTaxRateBasisPoints);

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
        vm.assume(taxRateBasisPoints < minTaxRateBasisPoints);

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

    function testStake(uint256 amount) public {
        vm.assume(amount > 500 ether && amount <= 1000000 ether);
        amount = 200000 ether;

        uint256 chipsCount = amount / _staking.SHARES_PER_CHIP();
        uint256 expectedStakedAmount = chipsCount * _staking.SHARES_PER_CHIP();

        _createNode(alice);

        vm.startPrank(bob);

        for (uint256 i = 1; i <= chipsCount; i++) {
            expectEmit();
            emit TestEvents.Transfer(address(0), bob, i);
        }
        expectEmit();
        emit Events.Staked(bob, alice, expectedStakedAmount, 1, chipsCount);

        _staking.stake{value: expectedStakedAmount}(alice);
        vm.stopPrank();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, expectedStakedAmount);
        assertEq(node.totalShares, chipsCount * _staking.SHARES_PER_CHIP());

        // stake to public pool will fail
        _createPublicGoodNode(bob);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(StakeToPublicGoodNode.selector, bob));
        _staking.stake{value: amount}(bob);
        vm.stopPrank();
    }

    function testStakeToPublicPool() public {
        uint256 amount = 10000 ether;

        _createPublicGoodNode(alice);

        uint256 chipsCount = amount / _staking.SHARES_PER_CHIP();

        vm.prank(alice);
        _staking.stakeToPublicPool{value: amount}(alice);

        assertEq(_staking.getPublicPool().stakingPoolTokens, amount);
        assertEq(_staking.getPublicPool().totalShares, chipsCount * _staking.SHARES_PER_CHIP());
    }

    function testStakeToPublicPoolFailToNonPublicGoodNode() public {
        // stake to public pool with non public good node will fail
        _createNode(bob);

        vm.expectRevert(abi.encodeWithSelector(NodeNotPublicGood.selector, bob));
        _staking.stakeToPublicPool{value: 1}(bob);
    }

    function testStakeToPublicPoolFailToNonExistentNode() public {
        // stake to public pool with empty node addr will fail
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.stakeToPublicPool{value: 1}(address(0xabc));
    }

    function testStakeToPublicPoolFailWithInsufficientValue() public {
        _createPublicGoodNode(alice);

        // stake to public pool with zero amount will fail
        vm.expectRevert(abi.encodeWithSelector(AmountTooSmall.selector, 0));
        _staking.stakeToPublicPool{value: 0}(alice);

        // stake to public pool with insufficient value will fail
        vm.expectRevert(abi.encodeWithSelector(AmountTooSmall.selector, 400 ether));
        _staking.stakeToPublicPool{value: 400 ether}(alice);
    }

    function testStakeFailToNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.stake{value: 1}(alice);
    }

    function testStakeFailToPublicGoodNode() public {
        _createPublicGoodNode(alice);

        vm.expectRevert(abi.encodeWithSelector(StakeToPublicGoodNode.selector, alice));
        _staking.stake{value: 1}(alice);
    }

    function testStakeFailWithInsufficientValue() public {
        _createNode(alice);

        vm.expectRevert(abi.encodeWithSelector(AmountTooSmall.selector, 0));
        _staking.stake{value: 0}(alice);

        vm.expectRevert(abi.encodeWithSelector(AmountTooSmall.selector, 400 ether));
        _staking.stake{value: 400 ether}(alice);
    }

    function testStakeFailInSettlementPhase() public {
        _createNode(alice);

        vm.prank(address(_settlement));
        _staking.setSettlementPhase(true);

        vm.expectRevert(abi.encodeWithSelector(SettlementPhase.selector));
        _staking.stake{value: 10000 ether}(alice);
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
        _testRequestUnstakeFromNode(alice, true);
    }

    function testRequestUnstake() public {
        _disableAlphaPhase();

        _createNode(alice);
        _testRequestUnstakeFromNode(alice, false);
    }

    function testRequestUnstakeApprovedChips() public {
        _disableAlphaPhase();

        _createNode(alice);
        _testRequestUnstakeApprovedChipsFromNode(alice, false);
    }

    function testRequestUnstakeApprovedChip() public {
        _disableAlphaPhase();

        _createNode(alice);
        _testRequestUnstakeApprovedChipFromNode(alice, false);
    }

    function testRequestUnstakeWithTransferChip() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(bob);
        (uint256 startTokenId, uint256 endTokenId) = _staking.stake{value: amount}(alice);

        // request unstake
        uint256[] memory tokenIds = new uint256[](endTokenId - startTokenId + 1);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;

            // bob transfers chips to carol
            _chips.transferFrom(bob, carol, i);
        }
        vm.stopPrank();

        _disableAlphaPhase();

        // carol unstake
        vm.prank(carol);
        uint256 requestId = _staking.requestUnstake(alice, tokenIds);

        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, carol);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount);
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

        vm.expectRevert(abi.encodeWithSelector(EmptyChipsIds.selector));
        _staking.requestUnstake(alice, new uint256[](0));
    }

    function testRequestUnstakeFailInChipsNotSameOwner() public {
        _disableAlphaPhase();

        _createNode(alice);

        vm.startPrank(bob);
        (uint256 t1, ) = _staking.stake{value: 10000 ether}(alice);
        _chips.approve(carol, t1);

        vm.startPrank(carol);
        (uint256 t2, ) = _staking.stake{value: 10000 ether}(alice);

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

        (uint256 startTokenId, uint256 endTokenId) = _staking.stake{value: amount}(alice);

        // request unstake
        uint256[] memory tokenIds = new uint256[](endTokenId - startTokenId + 1);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;
        }
        _staking.requestUnstake(alice, tokenIds);

        // requestUnstake again will fail
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenIds[0]));
        _staking.requestUnstake(alice, tokenIds);

        vm.stopPrank();
    }

    function testClaimUnstake() public {
        _disableAlphaPhase();

        uint256 amount = 10000 ether;

        _createNode(alice);

        // stake
        vm.startPrank(bob);

        (uint256 startTokenId, uint256 endTokenId) = _staking.stake{value: amount}(alice);

        // request unstake
        uint256[] memory tokenIds = new uint256[](endTokenId - startTokenId + 1);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;
        }

        uint256 requestId = _staking.requestUnstake(alice, tokenIds);

        uint256[] memory requestIds = array(requestId);

        vm.expectRevert(abi.encodeWithSelector(ClaimTimeNotReady.selector));
        _staking.claimUnstake(requestIds);

        // claim unstake
        skip(stakeUnbondingPeriod);

        expectEmit();
        emit Events.UnstakeClaimed(requestId, alice, bob, amount);

        _staking.claimUnstake(requestIds);

        // claim again will fail
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, requestId));
        _staking.claimUnstake(requestIds);

        vm.stopPrank();
    }

    function testDistributeRewards() public {
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
        _staking.stake{value: stakeAmount}(alice);
        _staking.stake{value: stakeAmount}(bob);

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

        // new stake and price will goes up
        uint256 minTokens = _staking.minTokensToStake(alice);
        assert(minTokens > _staking.SHARES_PER_CHIP());
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

    function testSlashNodes() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _createNode(alice);
        _createNode(bob);

        _deposit(alice, depositedTokens);
        _deposit(bob, depositedTokens);

        _staking.stake{value: stakedTokens}(alice);
        _staking.stake{value: stakedTokens}(bob);

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * nodeSlashRateBasisPoints) / _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * userSlashRateBasisPoints) / _denominator();

        address[] memory nodeAddrs = array(alice, bob);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            expectEmit();
            emit Events.NodeSlashed(
                nodeAddrs[i],
                expectedSlashedTokensOnOperationPool,
                expectedSlashedTokensOnStakingPool
            );
        }
        vm.prank(address(_settlement));
        _staking.slashNodes(nodeAddrs);

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.slashedTokens, expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool);

        node = _staking.getNode(bob);
        assertEq(node.slashedTokens, expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool);

        (uint256 totalOperationTokens, uint256 totalStakingTokens) = _staking.getPoolInfo();
        assertEq(totalOperationTokens, 2 * depositedTokens - 2 * expectedSlashedTokensOnOperationPool);
        assertEq(totalStakingTokens, 2 * stakedTokens - 2 * expectedSlashedTokensOnStakingPool);

        // check treasury
        uint256 treasuryAmount = _getTreasuryAmount();
        assertEq(treasuryAmount, (expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) * 2);
    }

    function testCalcTax1(uint256 operationPool) public {
        // case 1: receives no tax rewards
        vm.assume(operationPool < 10000 ether);

        uint256 rewards = 10000 ether;
        uint256 stakingPool = 1000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 tax1, uint256 partialTax1) = _internalStakingTest.calculateReward(
            rewards,
            taxRateBasisPoints,
            operationPool,
            stakingPool
        );

        assertEq(tax1, _getFullTax(rewards, taxRateBasisPoints));
        assertEq(partialTax1, 0);
    }

    function testCalcTax2() public {
        // case 2: receives full tax rewards
        uint256 operationPool = minDeposit;
        uint256 stakeRatio;
        vm.assume(stakeRatio < 25);

        uint256 stakingPool = operationPool * stakeRatio;

        uint256 rewards = 10000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 tax, uint256 partialTax) = _internalStakingTest.calculateReward(
            rewards,
            taxRateBasisPoints,
            operationPool,
            stakingPool
        );

        assertEq(tax, partialTax);
    }

    function testCalcTax3(uint256 stakingPool) public view {
        // case 2: receives partial tax rewards
        uint256 operationPool = minDeposit;

        vm.assume(stakingPool > 25 * operationPool && stakeRatio < 100 * operationPool);

        uint256 rewards = 10000 ether;
        uint64 taxRateBasisPoints = _defaultTaxRateBasisPoints;

        (uint256 tax, uint256 partialTax) = _internalStakingTest.calculateReward(
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

    function _testRequestUnstakeFromNode(address nodeAddr, bool isPublicGood) internal {
        uint256 amount = 10000 ether;

        // stake
        vm.startPrank(bob);
        (uint256 startTokenId, uint256 endTokenId) = isPublicGood
            ? _staking.stakeToPublicPool{value: amount}(nodeAddr)
            : _staking.stake{value: amount}(nodeAddr);

        // request unstake
        uint256[] memory tokenIds = new uint256[](endTokenId - startTokenId + 1);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;
        }
        // chips should be burnt
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            expectEmit();
            emit TestEvents.Transfer(bob, address(0), i);
        }
        expectEmit();
        emit Events.UnstakeRequested(bob, nodeAddr, 1, amount, tokenIds);
        uint256 requestId = _staking.requestUnstake(nodeAddr, tokenIds);

        vm.stopPrank();

        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
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
        (uint256 startTokenId, uint256 endTokenId) = isPublicGood
            ? _staking.stakeToPublicPool{value: amount}(nodeAddr)
            : _staking.stake{value: amount}(nodeAddr);

        uint256 tokensCount = endTokenId - startTokenId + 1;
        uint256[] memory tokenIds = new uint256[](tokensCount);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;
        }

        // approve chips
        _chips.setApprovalForAll(carol, true);
        vm.stopPrank();

        vm.prank(carol);
        expectEmit();
        emit TestEvents.Transfer(bob, address(0), startTokenId);

        expectEmit();
        emit Events.UnstakeRequested(bob, nodeAddr, 1, amount, tokenIds);
        uint256 requestId = _staking.requestUnstake(nodeAddr, tokenIds);

        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
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
        (uint256 startTokenId, uint256 endTokenId) = isPublicGood
            ? _staking.stakeToPublicPool{value: amount}(nodeAddr)
            : _staking.stake{value: amount}(nodeAddr);
        uint256 tokensCount = endTokenId - startTokenId + 1;

        // approve only one chip
        vm.prank(bob);
        _chips.approve(carol, startTokenId);

        uint256[] memory singleTokenId = array(startTokenId);

        vm.prank(carol);
        expectEmit();
        emit TestEvents.Transfer(bob, address(0), startTokenId);
        expectEmit();
        uint256 unstakedAmount = amount / tokensCount;
        emit Events.UnstakeRequested(bob, nodeAddr, 1, unstakedAmount, singleTokenId);
        uint256 requestId = _staking.requestUnstake(nodeAddr, singleTokenId);
        // check status
        _checkUnstakeOneChip(nodeAddr, requestId, amount, unstakedAmount, isPublicGood);
    }

    function _checkUnstakeOneChip(
        address nodeAddr,
        uint256 requestId,
        uint256 stakedAmount,
        uint256 unstakedAmount,
        bool isPublicGood
    ) internal {
        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, unstakedAmount);

        // check node info
        DataTypes.Node memory node = isPublicGood ? _staking.getPublicPool() : _staking.getNode(nodeAddr);

        assertEq(node.stakingPoolTokens, stakedAmount - unstakedAmount);
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

    function _checkNodeProfile(address nodeAddr, string memory name, string memory description) internal {
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
    ) internal {
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        _checkNodeProfile(nodeAddr, name, description);
        assertEq(node.nodeId, nodeId);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.publicGood, publicGood);
        assertEq(node.alpha, alpha);
    }
}
