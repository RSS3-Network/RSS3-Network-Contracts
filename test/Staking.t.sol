// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import "forge-std/console.sol";

// import {console2} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Events} from "../src/libraries/Events.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";
import {IERC721Errors} from "../src/interfaces/IERC721Errors.sol";

contract StakingTest is CommonTest, IErrors, IERC721Errors {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        _setUp();
        // transfer tokens
        _rss3.transfer(alice, _initialAmount);
        _rss3.transfer(bob, _initialAmount);
        // transfer tokens to settlement contract
        _rss3.transfer(address(_settlement), 30000000 ether);
    }

    function testCreateNode(uint64 taxFraction, bool publicGood) public {
        vm.assume(taxFraction <= 10000);

        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(alice, name, description, taxFraction, publicGood);
        vm.prank(alice);
        _staking.createNode(alice, name, description, taxFraction, publicGood);

        // check node info
        _checkNode(alice, name, description, taxFraction, publicGood);
        assertEq(_staking.getNodeCount(), 1);

        DataTypes.Node[] memory nodes = _staking.getNodesWithPagination(0, 2);
        assertEq(nodes.length, 1);
        _checkNode(nodes[0].account, nodes[0].name, nodes[0].description, nodes[0].taxFraction, nodes[0].publicGood);
    }

    function testCreateNodeToZeroAddressFail() public {
        // create node to address(0) will fail
        vm.expectRevert(abi.encodeWithSelector(CreateNodeToZeroAddress.selector));
        _createNode(address(0));
    }

    function testDeposit(uint256 amount) public {
        vm.assume(amount > 10000 ether && amount < _initialAmount);

        _createNode(alice);

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);

        expectEmit();
        emit Transfer(alice, address(_staking), amount);
        expectEmit();
        emit Events.Deposited(alice, amount);
        _staking.deposit(amount);
        vm.stopPrank();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.operationPoolTokens, amount);
    }

    function testDeleteNode(address nodeAddr) public {
        vm.assume(nodeAddr != proxyAdmin && nodeAddr != address(0));

        _createNode(nodeAddr);

        expectEmit();
        emit Events.NodeDeleted(nodeAddr);
        vm.prank(nodeAddr);
        _staking.deleteNode(nodeAddr);

        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.account, address(0));
        assertEq(_staking.getNodeCount(), 0);
    }

    function testRequestWithdrawal() public {
        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.createNodeAndDeposit("Alice", "Alice's node", uint64(100), false, amount);

        uint256 requestId = _staking.requestWithdrawal(amount);

        // requestWithdrawl again will fail
        vm.expectRevert(abi.encodeWithSelector(DepositedTokensSlashedAll.selector));
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
        _rss3.approve(address(_staking), amount);
        _staking.createNodeAndDeposit("Alice", "Alice's node", uint64(100), false, amount);

        _rss3.approve(address(_staking), amount);
        _staking.deposit(amount);

        uint256 requestId = _staking.requestWithdrawal(2 * amount);
        vm.stopPrank();

        // check status
        DataTypes.WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, 2 * amount);
    }

    function testClaimWithdrawl() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.deposit(amount);

        uint256 requestId = _staking.requestWithdrawal(amount);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;

        vm.expectRevert(abi.encodeWithSelector(ClaimTimeNotReady.selector));
        _staking.claimWithdrawal(requestIds);

        skip(depositUnbondingPeriod);

        expectEmit();
        emit Transfer(address(_staking), alice, amount);
        expectEmit();
        emit Events.WithdrawalClaimed(requestId);
        _staking.claimWithdrawal(requestIds);

        // Claim again will fail
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, requestId));
        _staking.claimWithdrawal(requestIds);

        vm.stopPrank();
    }

    function testMultipleRequestAndClaimWithdrawl() public {
        _createNode(alice);

        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.deposit(amount);

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

    function testSetTaxFraction4Node(uint64 taxFraction) public {
        vm.assume(taxFraction <= _denominator());

        _createNode(alice);

        vm.startPrank(alice);
        expectEmit();
        emit Events.NodeTaxFractionSet(alice, taxFraction);
        _staking.setTaxFraction4Node(alice, taxFraction);
        vm.stopPrank();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.taxFraction, taxFraction);
    }

    function testStake(uint256 amount) public {
        vm.assume(amount > 500 ether && amount <= 1000000 ether);
        amount = 200000 ether;

        uint256 chipsCount = amount / _staking.SHARES_PER_CHIP();
        uint256 expectedStakedAmount = chipsCount * _staking.SHARES_PER_CHIP();

        _createNode(alice);

        vm.startPrank(bob);
        _rss3.approve(address(_staking), amount);

        expectEmit();
        emit Transfer(bob, address(_staking), expectedStakedAmount);
        for (uint256 i = 1; i <= chipsCount; i++) {
            expectEmit();
            emit TestEvents.Transfer(address(0), bob, i);
        }
        expectEmit();
        emit Events.Staked(bob, alice, expectedStakedAmount, 1, chipsCount);
        _staking.stake(alice, amount);
        vm.stopPrank();

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, expectedStakedAmount);
        assertEq(node.totalShares, chipsCount * _staking.SHARES_PER_CHIP());

        // stake to public pool will fail
        _createPublicGoodNode(bob);

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(PublicGoodNodeNotStaked.selector, bob));
        _staking.stake(bob, amount);
        vm.stopPrank();
    }

    function testStakeToPublicPool() public {
        uint256 amount = 10000 ether;

        _createPublicGoodNode(alice);

        uint256 chipsCount = amount / _staking.SHARES_PER_CHIP();

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);

        expectEmit();
        emit Transfer(alice, address(_staking), amount);
        _staking.stakeToPublicPool(alice, amount);
        vm.stopPrank();

        _staking.getNode(alice);

        assertEq(_staking.getPublicPool().stakingPoolTokens, amount);
        assertEq(_staking.getPublicPool().totalShares, chipsCount * _staking.SHARES_PER_CHIP());

        // stake to public pool with non public good node will fail
        _createNode(bob);
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(NodeNotPublicGood.selector, bob));
        _staking.stakeToPublicPool(bob, amount);
        vm.stopPrank();

        // stake to public pool with empty node addr will fail
        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector));
        _staking.stakeToPublicPool(address(0xabc), amount);
        vm.stopPrank();
    }

    function testRequestUnstake() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        // stake
        vm.startPrank(bob);

        _rss3.approve(address(_staking), amount);
        (uint256 startTokenId, uint256 endTokenId) = _staking.stake(alice, amount);

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

        uint256 requestId = _staking.requestUnstake(alice, tokenIds);

        // requestUnstake again will fail
        vm.expectRevert(abi.encodeWithSelector(ERC721NonexistentToken.selector, tokenIds[0]));
        _staking.requestUnstake(alice, tokenIds);

        vm.stopPrank();

        // check status
        DataTypes.UnstakeRequest memory req = _staking.getPendingUnstake(requestId);
        assertEq(req.owner, bob);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, amount);

        // check node info
        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.stakingPoolTokens, 0);
        assertEq(node.totalShares, 0);
    }

    function testClaimUnstake() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        // stake
        vm.startPrank(bob);

        _rss3.approve(address(_staking), amount);
        (uint256 startTokenId, uint256 endTokenId) = _staking.stake(alice, amount);

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
        emit Transfer(address(_staking), bob, amount);
        expectEmit();
        emit Events.UnstakeClaimed(requestId, alice, bob, amount);

        _staking.claimUnstake(requestIds);

        // claim again will fail
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector, requestId));
        _staking.claimUnstake(requestIds);

        vm.stopPrank();
    }

    function testSetTaxFraction4PublicPool(uint64 expectedTaxFraction) public {
        vm.assume(expectedTaxFraction <= _denominator());

        vm.startPrank(oracleAccount);
        expectEmit();
        emit Events.PublicPoolTaxFractionSet(expectedTaxFraction);
        _staking.setTaxFraction4PublicPool(expectedTaxFraction);
        vm.stopPrank();

        uint64 realTaxFraction = _staking.getPublicPool().taxFraction;

        assertEq(realTaxFraction, expectedTaxFraction);
    }

    function testDistributeRewards() public {
        uint256 amount = 10000 ether;

        _createNode(alice);

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.deposit(amount);
        vm.stopPrank();

        // stake
        vm.startPrank(bob);

        _rss3.approve(address(_staking), amount);
        (uint256 startTokenId, uint256 endTokenId) = _staking.stake(alice, amount);
        uint256 chipsCount = endTokenId - startTokenId + 1;

        vm.stopPrank();

        // distribute rewards
        uint256[] memory requestFees = new uint256[](1);
        requestFees[0] = 1 ether;

        uint256[] memory requestBonuses = new uint256[](1);
        requestBonuses[0] = 1 ether;

        uint256[] memory stakingRewards = new uint256[](1);
        stakingRewards[0] = 1 ether;

        vm.startPrank(oracleAccount);
        uint256 startTime = block.timestamp;

        skip(18 hours);

        uint256 endTime = block.timestamp;

        address[] memory nodeAddrs = new address[](1);
        nodeAddrs[0] = alice;

        uint256[] memory taxAmounts = new uint256[](1);
        taxAmounts[0] = _getFullTax(requestFees[0] + stakingRewards[0], _defaultTaxFraction);
        expectEmit();

        emit Events.RewardDistributed(
            1,
            startTime,
            endTime,
            nodeAddrs,
            requestFees,
            requestBonuses,
            stakingRewards,
            taxAmounts
        );
        _staking.distributeRewards(
            [1, startTime, endTime],
            nodeAddrs,
            requestFees,
            requestBonuses,
            stakingRewards,
            1 ether // public pool reward
        );

        vm.stopPrank();

        _checkDistribution(amount, nodeAddrs, taxAmounts, requestFees, requestBonuses, stakingRewards);

        uint256[] memory tokenIds = new uint256[](chipsCount);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            tokenIds[i - startTokenId] = i;
        }

        // new stake and price will goes up
        vm.startPrank(bob);
        uint256 minTokens = _staking.minTokensToStake(alice);
        assert(minTokens > _staking.SHARES_PER_CHIP());

        _rss3.approve(address(_staking), minTokens);

        vm.stopPrank();

        _unstakeAndCheckAmount(bob, amount, tokenIds, taxAmounts, requestBonuses, stakingRewards);
    }

    function testWithdraw2Treasury() public {
        _createNode(alice);

        uint256 amount = 10000 ether;
        vm.startPrank(bob);
        _rss3.approve(address(_staking), amount);
        _staking.stake(alice, amount);
        vm.stopPrank();

        vm.startPrank(oracleAccount);
        address[] memory nodeAddrs = new address[](1);
        nodeAddrs[0] = alice;

        uint256[] memory requestFees = new uint256[](1);
        requestFees[0] = 0 ether;

        uint256[] memory requestCounts = new uint256[](1);
        requestCounts[0] = 0;

        _settlement.distributeRewards(nodeAddrs, requestFees, requestCounts);

        (uint256 operationPool, uint256 stakingPool, uint256 treasury) = _staking.getPoolInfo();
        assertEq(operationPool, 0);
        assert(treasury > 0);
        assert(stakingPool > 0);
    }

    function testCalcTax1(uint256 operationPool) public {
        // case 1: receives no tax rewards
        vm.assume(operationPool < 10000 ether);

        uint256 rewards = 10000 ether;
        uint256 stakingPool = 1000 ether;
        uint64 taxFraction = _defaultTaxFraction;

        (uint256 tax1, uint256 partialTax1) = _internalStakingTest.calculateReward(
            rewards,
            taxFraction,
            operationPool,
            stakingPool
        );

        assertEq(tax1, _getFullTax(rewards, taxFraction));
        assertEq(partialTax1, 0);
    }

    function testCalcTax2() public {
        // case 2: receives full tax rewards
        uint256 operationPool = minDeposit;
        uint256 stakeRatio;
        vm.assume(stakeRatio < 25);

        uint256 stakingPool = operationPool * stakeRatio;

        uint256 rewards = 10000 ether;
        uint64 taxFraction = _defaultTaxFraction;

        (uint256 tax, uint256 partialTax) = _internalStakingTest.calculateReward(
            rewards,
            taxFraction,
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
        uint64 taxFraction = _defaultTaxFraction;

        (uint256 tax, uint256 partialTax) = _internalStakingTest.calculateReward(
            rewards,
            taxFraction,
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

    function _unstakeAndCheckAmount(
        address sender,
        uint256 amount,
        uint256[] memory tokenIds,
        uint256[] memory taxAmounts,
        uint256[] memory requestBonuses,
        uint256[] memory stakingRewards
    ) internal {
        vm.startPrank(sender);

        uint256 requestId = _staking.requestUnstake(alice, tokenIds);
        skip(22.5 days);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0] = requestId;
        expectEmit();
        uint256 allRewards = amount + requestBonuses[0] + stakingRewards[0] - taxAmounts[0];
        emit Transfer(address(_staking), bob, allRewards);
        _staking.claimUnstake(requestIds);
        vm.stopPrank();
    }

    function _checkDistribution(
        uint256 amount,
        address[] memory nodeAddrs,
        uint256[] memory taxAmounts,
        uint256[] memory requestFees,
        uint256[] memory requestBonuses,
        uint256[] memory stakingRewards
    ) internal {
        // status check
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node memory node = _staking.getNode(nodeAddrs[i]);
            uint256 newOperationPool = amount + requestFees[i] + taxAmounts[i];
            assertEq(node.operationPoolTokens, newOperationPool);

            uint256 newstakingPool = amount + requestBonuses[i] + stakingRewards[i] - taxAmounts[i];
            assertEq(node.stakingPoolTokens, newstakingPool);
        }
    }

    function _checkNode(
        address nodeAddr,
        string memory name,
        string memory description,
        uint64 taxFraction,
        bool publicGood
    ) internal {
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.taxFraction, taxFraction);
        assertEq(node.publicGood, publicGood);
    }

    function _denominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _getFullTax(uint256 rewards, uint64 taxFraction) internal pure returns (uint256) {
        return (rewards * taxFraction) / _denominator();
    }
}
