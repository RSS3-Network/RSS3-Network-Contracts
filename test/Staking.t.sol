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
                    reservedData: 0
                })
            )
        );

        // check an empty chip
        (address nodeAddr, uint256 tokens, uint256 shares) = _staking.getChipInfo(1);
        assertEq(nodeAddr, address(0));
        assertEq(tokens, 0);
        assertEq(shares, 0);
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

    function testDepositFailWithStakeAmountTooSmall() public {
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
        _staking.stake{value: 1}(alice);
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

    function testStakeToPublicPoolFailToNonExistentNode() public {
        // stake to public pool with empty node addr will fail
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.stakeToPublicPool{value: 1}(address(0xabc));
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

    function testRecordSlashingFail() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        address[] memory nodeAddrs = array(alice, bob);
        address[] memory reporters = array(carol, dave);
        uint256[] memory epochIds = array(123, 123);

        uint256[] memory wrongEpochIds = array(123);
        address[] memory wrongReporters = array(carol);

        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _staking.recordSlashing(nodeAddrs, reporters, wrongEpochIds);

        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _staking.recordSlashing(nodeAddrs, wrongReporters, epochIds);

        address[] memory emptyNodeAddrs = array(alice, address(0x0));
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        vm.prank(address(_settlement));
        _staking.recordSlashing(emptyNodeAddrs, reporters, epochIds);

        address[] memory sameNodeAddrs = array(alice, alice);
        vm.expectRevert(abi.encodeWithSelector(SlashMoreThanOnce.selector, alice, 123));
        vm.prank(address(_settlement));
        _staking.recordSlashing(sameNodeAddrs, reporters, epochIds);

        _createPublicGoodNode(carol);
        address[] memory pgNodeAddrs = array(carol);
        address[] memory reporters2 = array(dave);
        uint256[] memory epochIds2 = array(123);
        vm.expectRevert(abi.encodeWithSelector(SlashPublicGoodNode.selector, carol));
        vm.prank(address(_settlement));
        _staking.recordSlashing(pgNodeAddrs, reporters2, epochIds2);
    }

    function testRecordSlashing() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * nodeSlashRateBasisPoints) / _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * userSlashRateBasisPoints) / _denominator();

        address[] memory nodeAddrs = array(alice, bob);
        address[] memory reporters = array(carol, dave);
        uint256[] memory epochIds = array(123, 123);

        uint256 slashId = 0;
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            expectEmit();
            emit Events.SlashRecorded(
                ++slashId,
                nodeAddrs[i],
                epochIds[i],
                reporters[i],
                expectedSlashedTokensOnOperationPool,
                expectedSlashedTokensOnStakingPool
            );
        }
        vm.prank(address(_settlement));
        _staking.recordSlashing(nodeAddrs, reporters, epochIds);

        uint256[] memory expectedSlashIds = array(1, 2);

        DataTypes.SlashRecord[] memory records = _staking.getSlashingRecords(expectedSlashIds);

        for (uint256 i = 0; i < records.length; i++) {
            assertEq(records[i].nodeAddr, nodeAddrs[i]);
            assertEq(records[i].epoch, epochIds[i]);
            assertEq(records[i].reporter, reporters[i]);
            assertEq(records[i].amountForOperationPool, expectedSlashedTokensOnOperationPool);
            assertEq(records[i].amountForStakingPool, expectedSlashedTokensOnStakingPool);
            vm.assume(records[i].status == DataTypes.SlashStatus.Recorded);
        }
    }

    function testCommitSlashingFail() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        address[] memory nodeAddrs = array(alice, bob);
        uint256[] memory epochIds = array(123, 123);

        address[] memory reporters = array(address(0xabc), address(0xdef));

        vm.startPrank(address(_settlement));

        // cannot commit a non-exist one
        vm.expectRevert(abi.encodeWithSelector(UnableToCommit.selector, 3));
        _staking.commitSlashing(array(3));

        _staking.recordSlashing(nodeAddrs, reporters, epochIds);

        // cannot commit a revoked one
        _staking.revokeSlashing(array(1));

        vm.expectRevert(abi.encodeWithSelector(UnableToCommit.selector, 1));
        _staking.commitSlashing(array(1));

        // cannot commit a committed one
        _staking.commitSlashing(array(2));

        vm.expectRevert(abi.encodeWithSelector(UnableToCommit.selector, 2));
        _staking.commitSlashing(array(2));

        vm.stopPrank();
    }

    function testCommitSlashing() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * nodeSlashRateBasisPoints) / _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * userSlashRateBasisPoints) / _denominator();

        _setUpNodes(depositedTokens, stakedTokens);
        uint256 treasuryAmount = _getTreasuryAmount();

        address[] memory nodeAddrs = array(alice, bob);
        uint256[] memory epochIds = array(123, 123);

        address[] memory reporters = array(address(0xabc), address(0xdef));

        uint256[] memory expectedSlashIds = array(1, 2);

        vm.prank(address(_settlement));
        _staking.recordSlashing(nodeAddrs, reporters, epochIds);

        uint256 stakingPoolTokens = _staking.getNode(alice).stakingPoolTokens;
        uint256 operationPoolTokens = _staking.getNode(alice).operationPoolTokens;

        assertEq(treasuryAmount, 0);

        expectEmit();
        emit Events.SlashCommitted(expectedSlashIds);
        vm.prank(address(_settlement));
        _staking.commitSlashing(expectedSlashIds);

        for (uint256 i = 0; i < expectedSlashIds.length; i++) {
            uint256 value = ((expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) *
                slashReporterBonusRateBasisPoints) / _denominator();
            assertEq(reporters[i].balance, value);
        }

        uint256 treasuryAmountAfterSlashing = _getTreasuryAmount();
        uint256 expectedTreasuryAmount = 2 *
            (expectedSlashedTokensOnOperationPool +
                expectedSlashedTokensOnStakingPool -
                (((expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) *
                    (slashReporterBonusRateBasisPoints)) / _denominator()));

        assertEq(treasuryAmountAfterSlashing, expectedTreasuryAmount);

        assertEq(_staking.getNode(alice).stakingPoolTokens, stakingPoolTokens - expectedSlashedTokensOnStakingPool);
        assertEq(
            _staking.getNode(alice).operationPoolTokens,
            operationPoolTokens - expectedSlashedTokensOnOperationPool
        );

        DataTypes.SlashRecord[] memory records = _staking.getSlashingRecords(expectedSlashIds);

        for (uint256 i = 0; i < records.length; i++) {
            vm.assume(records[i].status == DataTypes.SlashStatus.Committed);
        }
    }

    function testRevokeSlashingFail() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        address[] memory nodeAddrs = array(alice, bob);
        uint256[] memory epochIds = array(123, 123);

        address[] memory reporters = array(address(0xabc), address(0xdef));

        _setUpNodes(depositedTokens, stakedTokens);
        vm.startPrank(address(_settlement));

        vm.expectRevert(abi.encodeWithSelector(UnableToRevoke.selector, 1));
        _staking.revokeSlashing(array(1));

        _staking.recordSlashing(nodeAddrs, reporters, epochIds);
        // Cannot revoke a revoked one

        _staking.revokeSlashing(array(1));

        vm.expectRevert(abi.encodeWithSelector(UnableToRevoke.selector, 1));
        _staking.revokeSlashing(array(1));

        // Cannot revoke a committed one
        _staking.commitSlashing(array(2));

        vm.expectRevert(abi.encodeWithSelector(UnableToRevoke.selector, 2));
        _staking.revokeSlashing(array(2));

        vm.stopPrank();
    }

    function testRevokeSlashing() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;
        _setUpNodes(depositedTokens, stakedTokens);

        vm.startPrank(address(_settlement));
        _staking.recordSlashing(array(alice, bob), array(carol, dave), array(123, 123));

        uint256[] memory expectedSlashIds = array(1, 2);
        expectEmit();
        emit Events.SlashRevoked(expectedSlashIds);
        _staking.revokeSlashing(expectedSlashIds);

        vm.stopPrank();
    }

    function testRecordSlashingMulti() public {
        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        _setUpNodes(depositedTokens, stakedTokens);

        address[] memory reporters = array(carol, dave);
        uint256[] memory epochIds = array(123, 123);

        vm.startPrank(address(_settlement));
        _staking.recordSlashing(array(alice, bob), reporters, epochIds); // 1, 2
        // revoke first and record again
        _staking.revokeSlashing(array(1));
        _staking.recordSlashing(array(alice), array(dave), array(123)); // 3
        _staking.commitSlashing(array(2, 3));

        // finally check treasury
        uint256 treasuryAmount = _getTreasuryAmount();

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * nodeSlashRateBasisPoints) / _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * userSlashRateBasisPoints) / _denominator();

        uint256 expectedTreasuryAmount = 2 *
            (expectedSlashedTokensOnOperationPool +
                expectedSlashedTokensOnStakingPool -
                (((expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool) *
                    (slashReporterBonusRateBasisPoints)) / _denominator()));
        assertEq(treasuryAmount, expectedTreasuryAmount);

        DataTypes.Node memory aliceNode = _staking.getNode(alice);

        uint256 expectedSlashedTokensOnOperationPool2 = (aliceNode.operationPoolTokens * nodeSlashRateBasisPoints) /
            _denominator();
        uint256 expectedSlashedTokensOnStakingPool2 = (aliceNode.stakingPoolTokens * userSlashRateBasisPoints) /
            _denominator();

        uint256 expectedTreasuryAmount2 = 2 *
            (expectedSlashedTokensOnOperationPool2 +
                expectedSlashedTokensOnStakingPool2 -
                (((expectedSlashedTokensOnOperationPool2 + expectedSlashedTokensOnStakingPool2) *
                    (slashReporterBonusRateBasisPoints)) / _denominator()));

        // record same addr twice
        address[] memory sameNodeAddrs = array(alice, alice);
        uint256[] memory diffEpochIds = array(124, 125);
        _staking.recordSlashing(sameNodeAddrs, reporters, diffEpochIds); // 4, 5
        _staking.commitSlashing(array(4, 5));

        uint256 treasuryAmount2 = _getTreasuryAmount();
        assertEq(treasuryAmount2, expectedTreasuryAmount2);
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

    function _setUpNodes(uint256 depositedTokens, uint256 stakedTokens) internal {
        _createNode(alice);
        _createNode(bob);

        _deposit(alice, depositedTokens);
        _deposit(bob, depositedTokens);

        _staking.stake{value: stakedTokens}(alice);
        _staking.stake{value: stakedTokens}(bob);
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
