// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

// import {console2} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Events} from "../src/libraries/Events.sol";
import {IErrors} from "../src/interfaces/IErrors.sol";

contract StakingTest is CommonTest, IErrors {
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        _setUp();

        // transfer tokens
        _rss3.transfer(alice, _initialAmount);
        _rss3.transfer(bob, _initialAmount);
    }

    function testCreateNode(uint64 taxFraction, bool publicGood) public {
        vm.assume(taxFraction <= 10000);

        string memory name = "Alice";
        string memory description = "Alice's node";
        string memory endpoint = "https://alice.com";

        expectEmit();
        emit Events.NodeCreated(alice, name, description, taxFraction, publicGood, endpoint);
        vm.prank(alice);
        _staking.createNode(alice, name, description, taxFraction, publicGood, endpoint);

        // check node info
        _checkNode(alice, name, description, taxFraction, publicGood, endpoint);
        assertEq(_staking.getNodeCount(), 1);

        DataTypes.Node[] memory nodes = _staking.getNodes(0, 2);
        assertEq(nodes.length, 1);
        _checkNode(
            nodes[0].account,
            nodes[0].name,
            nodes[0].description,
            nodes[0].taxFraction,
            nodes[0].publicGood,
            nodes[0].endpoint
        );
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
        assertEq(node.operatorPool, amount);
    }

    function testDeleteNode(address nodeAddr) public {
        _createNode(nodeAddr);

        vm.startPrank(nodeAddr);
        expectEmit();
        emit Events.NodeDeleted(nodeAddr);
        _staking.deleteNode(nodeAddr);
        vm.stopPrank();

        assertEq(_staking.getNodeCount(), 0);

        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.account, address(0));
    }

    function testRequestWithdrawal() public {
        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.createNodeAndDeposit("Alice", "Alice's node", uint64(100), false, "https://alice.com", amount);

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
    }

    function testMultipleDepositAndRequestWithdrawal() public {
        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.createNodeAndDeposit("Alice", "Alice's node", uint64(100), false, "https://alice.com", amount);

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

        uint256 balanceBefore = _rss3.balanceOf(address(alice));

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
        emit Events.WithdrawalClaimed(requestId);
        _staking.claimWithdrawal(requestIds);

        uint256 balanceAfter = _rss3.balanceOf(address(alice));
        assertEq(balanceBefore, balanceAfter);

        // Claim again will fail
        vm.expectRevert(abi.encodeWithSelector(ClaimIdNotExists.selector));
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

        uint i = 0;
        for (uint v = 0; v < amount; v += value) {
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

        // create node
        vm.startPrank(alice);
        _rss3.approve(address(_staking), 10000 ether);
        _staking.deposit(10000 ether);
        vm.stopPrank();

        // stake
        vm.startPrank(bob);
        _rss3.approve(address(_staking), amount);

        for (uint256 i = 1; i <= chipsCount; i++) {
            expectEmit();
            emit TestEvents.Transfer(address(0), bob, i);
        }
        expectEmit();
        emit Transfer(bob, address(_staking), expectedStakedAmount);
        expectEmit();
        emit Events.Staked(bob, alice, expectedStakedAmount, 1, chipsCount);
        _staking.stake(alice, amount);
        vm.stopPrank();
    }

    function _checkNode(
        address nodeAddr,
        string memory name,
        string memory description,
        uint64 taxFraction,
        bool publicGood,
        string memory endpoint
    ) internal {
        DataTypes.Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.taxFraction, taxFraction);
        assertEq(node.publicGood, publicGood);
        assertEq(node.endpoint, endpoint);
    }

    function _createNode(address to) internal {
        vm.prank(to);
        _staking.createNode(to, "Name", "Description", uint64(1000), false, "https://domain.com");
    }

    function _denominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
