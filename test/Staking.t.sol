// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {Events} from "../src/libraries/Events.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {IERC721Errors} from "../src/interfaces/IERC721Errors.sol";

contract StakingTest is CommonTest, IErrors, IERC721Errors {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

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
        assertEq(_staking.getMinDeposit(), minDeposit);
        assertEq(_staking.chipsContract(), address(_chips));

        assertEq(_staking.STAKE_UNBONDING_PERIOD(), stakeUnbondingPeriod);
        assertEq(_staking.DEPOSIT_UNBONDING_PERIOD(), depositUnbondingPeriod);
        assertEq(_staking.NODE_SLASH_RATE_BASIS_POINTS(), nodeSlashRateBasisPoints);
        assertEq(_staking.USER_SLASH_RATE_BASIS_POINTS(), userSlashRateBasisPoints);
        assertEq(_staking.STAKE_RATIO(), stakeRatio);
        assertEq(_staking.TREASURY(), treasury);
        assertEq(_staking.SHARES_PER_CHIP(), 500 ether);

        vm.mockCall(
            address(_staking),
            abi.encodeWithSelector(Staking.getPublicPool.selector),
            abi.encode(
                DataTypes.Node({
                    account: address(0),
                    taxRateBasisPoints: 0,
                    publicGood: false,
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

    function testCreateNode(uint64 taxRateBasisPoints, bool publicGood) public {
        vm.assume(taxRateBasisPoints <= 10000);

        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(alice, name, description, taxRateBasisPoints, publicGood);
        vm.prank(alice);
        _staking.createNode(name, description, taxRateBasisPoints, publicGood);

        // check node info
        _checkNode(alice, name, description, taxRateBasisPoints, 0, publicGood);
        assertEq(_staking.getNodeCount(), 1);
    }

    function testCreateNodeWithDeposit(uint64 taxRateBasisPoints, uint256 amount) public {
        vm.assume(taxRateBasisPoints <= 10000);
        vm.assume(amount > 1 && amount < _initialAmount);

        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(alice, name, description, taxRateBasisPoints, false);
        expectEmit();
        emit Events.Deposited(alice, amount);

        vm.prank(alice);
        _staking.createNode{value: amount}(name, description, taxRateBasisPoints, false);

        // check node info
        _checkNode(alice, name, description, taxRateBasisPoints, amount, false);
        assertEq(_staking.getNodeCount(), 1);
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

    function testDeleteNode(address nodeAddr) public {
        vm.assume(nodeAddr != proxyAdmin && nodeAddr != address(0));

        _createNode(nodeAddr);

        expectEmit();
        emit Events.NodeDeleted(nodeAddr);
        vm.prank(nodeAddr);
        _staking.deleteNode();

        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.account, address(0));
        assertEq(_staking.getNodeCount(), 0);
    }

    function testDeleteNodeFailWithNodeDeposited(address nodeAddr) public {
        vm.assume(nodeAddr != proxyAdmin && nodeAddr != address(0));

        _createNode(nodeAddr);

        vm.deal(nodeAddr, 100 ether);

        vm.startPrank(nodeAddr);
        _staking.deposit{value: 100 ether}();

        vm.expectRevert(abi.encodeWithSelector(NodeStakedOrDeposited.selector));
        _staking.deleteNode();
        vm.stopPrank();
    }

    function testDeleteNodeFailWithNodeStaked(address nodeAddr) public {
        vm.assume(nodeAddr != proxyAdmin && nodeAddr != address(0));

        _createNode(nodeAddr);

        vm.prank(alice);
        _staking.stake{value: 1000 ether}(nodeAddr);

        vm.expectRevert(abi.encodeWithSelector(NodeStakedOrDeposited.selector));
        vm.prank(nodeAddr);
        _staking.deleteNode();
    }

    function testDeleteNodeFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        vm.prank(dave);
        _staking.deleteNode();
    }

    function testRequestWithdrawal() public {
        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _staking.createNode{value: amount}("Alice", "Alice's node", uint64(100), false);

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
        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _staking.createNode{value: amount}("Alice", "Alice's node", uint64(100), false);

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
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        vm.expectRevert(abi.encodeWithSelector(ExcessWithdrawalAmount.selector));
        _staking.requestWithdrawal(amount + 1);
        vm.stopPrank();
    }

    function testRequestWithdrawalFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.requestWithdrawal(1 ether);
    }

    function testClaimWithdrawal() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        uint256 requestId = _staking.requestWithdrawal(amount);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;

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
        _createNode(alice);

        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        uint256 value = 100 ether;
        assertEq(amount % value, 0);

        uint256[] memory requestIds = new uint256[](amount / value);

        uint256 i = 0;
        for (uint256 v = 0; v < amount; v += value) {
            requestIds[i] = _staking.requestWithdrawal(value);
            i++;
        }

        skip(depositUnbondingPeriod);

        _staking.claimWithdrawal(requestIds);

        vm.stopPrank();
    }

    function testSetTaxRate4Node(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints <= _denominator());

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

        vm.startPrank(oracleAccount);
        expectEmit();
        emit Events.PublicPoolTaxRateBasisPointsSet(expectedTaxRateBasisPoints);
        _staking.setTaxRateBasisPoints4PublicPool(expectedTaxRateBasisPoints);
        vm.stopPrank();

        uint64 realTaxRateBasisPoints = _staking.getPublicPool().taxRateBasisPoints;

        assertEq(realTaxRateBasisPoints, expectedTaxRateBasisPoints);
    }

    function testSetTaxRateError(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints > _denominator());
        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
        vm.prank(alice);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
        vm.prank(oracleAccount);
        _staking.setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
    }

    function testSetTaxRateFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        vm.prank(dave);
        _staking.setTaxRateBasisPoints4Node(100);
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
        vm.expectRevert(abi.encodeWithSelector(InsufficientValue.selector));
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

        vm.expectRevert(abi.encodeWithSelector(InsufficientValue.selector));
        _staking.stake{value: 0}(alice);

        vm.expectRevert(abi.encodeWithSelector(AmountTooSmall.selector, 400 ether));
        _staking.stake{value: 400 ether}(alice);
    }

    function testRequestUnstakeFromPublic() public {
        _createPublicGoodNode(alice);
        _testRequestUnstakeFromNode(alice, true);
    }

    function testRequestUnstake() public {
        _createNode(alice);
        _testRequestUnstakeFromNode(alice, false);
    }

    function testRequestUnstakeFailWithBurnedChip() public {
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

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;

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
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.prank(alice);
        _staking.deposit{value: amount}();

        // stake
        vm.prank(bob);
        (uint256 startTokenId, uint256 endTokenId) = _staking.stake{value: amount}(alice);
        uint256 chipsCount = endTokenId - startTokenId + 1;

        // distribute rewards
        uint256[] memory requestFees = new uint256[](1);
        requestFees[0] = 1 ether;

        uint256[] memory operationRewards = new uint256[](1);
        operationRewards[0] = 1 ether;

        uint256[] memory stakingRewards = new uint256[](1);
        stakingRewards[0] = 1 ether;

        uint256 startTime = block.timestamp;

        skip(19 hours);

        uint256 endTime = block.timestamp;

        address[] memory nodeAddrs = new address[](1);
        nodeAddrs[0] = alice;

        uint256[] memory taxAmounts = new uint256[](1);
        taxAmounts[0] = _getFullTax(requestFees[0] + stakingRewards[0], _defaultTaxRateBasisPoints);
        expectEmit();

        emit Events.RewardDistributed(
            1,
            startTime,
            endTime,
            nodeAddrs,
            requestFees,
            operationRewards,
            stakingRewards,
            taxAmounts
        );
        vm.prank(oracleAccount);
        _staking.distributeRewards(
            [1, startTime, endTime],
            nodeAddrs,
            requestFees,
            operationRewards,
            stakingRewards,
            1 ether // public pool reward
        );

        _checkDistribution(amount, nodeAddrs, taxAmounts, requestFees, operationRewards, stakingRewards);

        uint256[] memory tokenIds = new uint256[](chipsCount);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;
        }

        // new stake and price will goes up
        vm.startPrank(bob);
        uint256 minTokens = _staking.minTokensToStake(alice);
        assert(minTokens > _staking.SHARES_PER_CHIP());

        vm.stopPrank();

        _unstakeAndCheckAmount(bob, amount, tokenIds, taxAmounts, operationRewards, stakingRewards);
    }

    function testWithdraw2Treasury() public {
        _createNode(alice);

        uint256 amount = 10000 ether;
        vm.prank(bob);
        _staking.stake{value: amount}(alice);

        address[] memory nodeAddrs = new address[](1);
        nodeAddrs[0] = alice;

        uint256[] memory requestFees = new uint256[](1);
        requestFees[0] = 0 ether;

        uint256[] memory requestCounts = new uint256[](1);
        requestCounts[0] = 0;

        skip(18 hours);

        vm.prank(oracleAccount);
        _settlement.distributeRewards(1, nodeAddrs, requestFees, requestCounts);

        (uint256 operationPool, uint256 stakingPool, uint256 treasury) = _staking.getPoolInfo();
        assertEq(operationPool, 0);
        assert(treasury > 0);
        assert(stakingPool > 0);
    }

    function testSlashNodes() public {
        _createNode(alice);
        _createNode(bob);

        uint256 depositedTokens = 10000 ether;
        uint256 stakedTokens = 40000 ether;

        vm.startPrank(alice);
        _staking.deposit{value: depositedTokens}();
        vm.stopPrank();

        vm.startPrank(bob);
        _staking.deposit{value: depositedTokens}();
        vm.stopPrank();

        vm.startPrank(carol);
        _staking.stake{value: stakedTokens}(alice);
        _staking.stake{value: stakedTokens}(bob);
        vm.stopPrank();

        uint256 expectedSlashedTokensOnOperationPool = (depositedTokens * nodeSlashRateBasisPoints) / _denominator();
        uint256 expectedSlashedTokensOnStakingPool = (stakedTokens * userSlashRateBasisPoints) / _denominator();

        vm.startPrank(oracleAccount);

        address[] memory nodeAddrs = new address[](2);
        nodeAddrs[0] = alice;
        nodeAddrs[1] = bob;

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            expectEmit();
            emit Events.NodeSlashed(
                nodeAddrs[i],
                expectedSlashedTokensOnOperationPool,
                expectedSlashedTokensOnStakingPool
            );
        }
        _staking.slashNodes(nodeAddrs);
        vm.stopPrank();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.slashedTokens, expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool);

        node = _staking.getNode(bob);
        assertEq(node.slashedTokens, expectedSlashedTokensOnOperationPool + expectedSlashedTokensOnStakingPool);

        (uint256 totalOperationTokens, uint256 totalStakingTokens, uint256 treasuryAmount) = _staking.getPoolInfo();
        assertEq(totalOperationTokens, 2 * depositedTokens - 2 * expectedSlashedTokensOnOperationPool);
        assertEq(totalStakingTokens, 2 * stakedTokens - 2 * expectedSlashedTokensOnStakingPool);
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

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;

        uint256 allRewards = amount + operationRewards[0] + stakingRewards[0] - taxAmounts[0];

        uint256 balBefore = sender.balance;

        _staking.claimUnstake(requestIds);

        uint256 balAfter = sender.balance;

        assertEq(balAfter - balBefore, allRewards);

        vm.stopPrank();
    }

    function _checkDistribution(
        uint256 amount,
        address[] memory nodeAddrs,
        uint256[] memory taxAmounts,
        uint256[] memory requestFees,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards
    ) internal {
        // status check
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node memory node = _staking.getNode(nodeAddrs[i]);
            uint256 newOperationPool = amount + requestFees[i] + taxAmounts[i];
            assertEq(node.operationPoolTokens, newOperationPool);

            uint256 newstakingPool = amount + operationRewards[i] + stakingRewards[i] - taxAmounts[i];
            assertEq(node.stakingPoolTokens, newstakingPool);
        }
    }

    function _checkNode(
        address nodeAddr,
        string memory name,
        string memory description,
        uint64 taxRateBasisPoints,
        uint256 operationPoolTokens,
        bool publicGood
    ) internal {
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.publicGood, publicGood);
    }

    function _denominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints) internal pure returns (uint256) {
        return (rewards * taxRateBasisPoints) / _denominator();
    }
}
