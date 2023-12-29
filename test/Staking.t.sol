// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

//import {console2 as console} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Events} from "../src/libraries/Events.sol";

contract StakingTest is CommonTest {
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
    }

    function testRequestWithdrawal() public {
        uint256 amount = 10000 ether;

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);
        _staking.createNodeAndDeposit(
            "Alice",
            "Alice's node",
            uint64(100),
            false,
            "https://alice.com",
            amount
        );

        uint256 requestId = _staking.requestWithdrawal(amount);
        vm.stopPrank();

        // check status
        DataTypes.WithdrawalRequest memory req = _staking.getPendingWithdrawal(requestId);
        assertEq(req.owner, alice);
        assertEq(req.isClaimed, false);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.amount, amount);
    }

    function testStake(uint256 amount) public {
        vm.assume(amount > 500 ether && amount <= 1000000 ether);

        uint256 chipsCount = amount / _staking.SHARES_PER_CHIP();
        uint256 expectedStakedAmount = chipsCount * _staking.SHARES_PER_CHIP();

        _createNode(alice);

        // stake
        vm.startPrank(alice);
        _rss3.approve(address(_staking), 10000 ether);
        _staking.deposit(10000 ether);
        vm.stopPrank();

        // delegate
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
}
