// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.24;

import {Const} from "../src/libraries/Const.sol";
import {Node, NodeStatus} from "../src/libraries/DataTypes.sol";
import {
    CurStateCantExit,
    CurStatusCantOnline,
    DepositForPublicGoodNode,
    InvalidArrayLength,
    NodeDepositBelowMinimum,
    NodeExists,
    NodeIsPublicGood,
    NodeNotExists,
    NodeNotInExitStatus,
    StatusNotAllowed,
    TaxRateBasisPointsOutOfRange
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";
import {CommonTest} from "./helpers/CommonTest.sol";
import {console2 as console} from "forge-std/console2.sol";

contract NodeSettingTest is CommonTest {
    function setUp() public {
        _setUp();

        vm.deal(alice, _initialAmount);
        vm.deal(bob, _initialAmount);
        vm.deal(carol, _initialAmount);
        vm.deal(dave, _initialAmount);

        vm.deal(address(_settlement), 30_000_000 ether);
    }

    function testCreateNode(uint64 taxRateBasisPoints) public {
        taxRateBasisPoints =
            uint64(bound(taxRateBasisPoints, Const.MIN_TAX_RATE_BASIS_POINTS, 10_000));

        string memory name = "Alice";
        string memory description = "Alice's node";

        // create a node
        expectEmit();
        emit Events.NodeCreated(1, alice, name, description, taxRateBasisPoints, false, false);
        vm.prank(alice);
        _staking.createNode(name, description, taxRateBasisPoints, false);

        // check node info
        _checkNode(alice, 1, name, description, taxRateBasisPoints, 0, false, false);
        assertEq(_staking.getNodeCount(), 1);
        // check node status
        assertEq(uint256(_staking.getNode(alice).status), uint256(NodeStatus.None));
    }

    function testCreatePGNode() public {
        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(1, alice, name, description, 0, true, false);
        vm.prank(alice);
        _staking.createNode(name, description, 0, true);

        // check node info
        _checkNode(alice, 1, name, description, 0, 0, true, false);
        assertEq(_staking.getNodeCount(), 1);
        // check node status
        assertEq(uint256(_staking.getNode(alice).status), uint256(NodeStatus.Registered));
    }

    function testCreateNodeWithDeposit(uint64 taxRateBasisPoints, uint256 amount) public {
        taxRateBasisPoints =
            uint64(bound(taxRateBasisPoints, Const.MIN_TAX_RATE_BASIS_POINTS, 10_000));
        amount = bound(amount, 1, _initialAmount);

        string memory name = "Alice";
        string memory description = "Alice's node";

        expectEmit();
        emit Events.NodeCreated(1, alice, name, description, taxRateBasisPoints, false, false);
        expectEmit();
        emit Events.Deposited(alice, amount);
        vm.prank(alice);
        _staking.createNode{value: amount}(name, description, taxRateBasisPoints, false);

        // check node info
        _checkNode(alice, 1, name, description, taxRateBasisPoints, amount, false, false);
        assertEq(_staking.getNodeCount(), 1);
        // check node status
        NodeStatus expectedStatus =
            amount >= Const.MIN_DEPOSIT ? NodeStatus.Registered : NodeStatus.None;
        assertEq(uint256(_staking.getNode(alice).status), uint256(expectedStatus));
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
        Node[] memory nodes2 = _staking.getNodes(array(alice, bob, carol, dave));
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
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.updateNode("New Alice", "New Alice's node");
    }

    function testCreateNodeFailWithMultipleNodes() public {
        _createNode(alice);

        vm.expectRevert(abi.encodeWithSelector(NodeExists.selector));
        _createNode(alice);
    }

    function testCreateNodeFailWithTaxRateOutOfRange(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints > 10_000 || taxRateBasisPoints < 500);

        vm.expectRevert(
            abi.encodeWithSelector(TaxRateBasisPointsOutOfRange.selector, taxRateBasisPoints)
        );
        _staking.createNode("Alice", "Alice's node", taxRateBasisPoints, false);
    }

    function testCreateNodeFailWithPublicGoodNodeDeposited() public {
        vm.expectRevert(abi.encodeWithSelector(DepositForPublicGoodNode.selector));
        _staking.createNode{value: 1}("Alice", "Alice's node", uint64(0), true);
    }

    function testSetTaxRate4Node(uint64 taxRateBasisPoints) public {
        taxRateBasisPoints =
            uint64(bound(taxRateBasisPoints, Const.MIN_TAX_RATE_BASIS_POINTS, Const.DENOMINATOR));

        _createNode(alice);

        vm.startPrank(alice);
        expectEmit();
        emit Events.NodeTaxRateBasisPointsSet(alice, taxRateBasisPoints);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);
        vm.stopPrank();

        Node memory node = _staking.getNode(alice);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
    }

    function testSetTaxRate4PublicPool(uint64 taxRateBasisPoints) public {
        taxRateBasisPoints =
            uint64(bound(taxRateBasisPoints, Const.MIN_TAX_RATE_BASIS_POINTS, Const.DENOMINATOR));

        vm.startPrank(address(_settlement));
        expectEmit();
        emit Events.PublicPoolTaxRateBasisPointsSet(taxRateBasisPoints);
        _staking.setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
        vm.stopPrank();

        uint64 realTaxRateBasisPoints = _staking.getPublicPool().taxRateBasisPoints;

        assertEq(realTaxRateBasisPoints, taxRateBasisPoints);
    }

    function testSetTaxRateFailWithTaxRateOutOfRange(uint64 taxRateBasisPoints) public {
        vm.assume(
            taxRateBasisPoints > Const.DENOMINATOR
                || taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS
        );

        vm.expectRevert(
            abi.encodeWithSelector(TaxRateBasisPointsOutOfRange.selector, taxRateBasisPoints)
        );
        vm.prank(alice);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);

        vm.expectRevert(
            abi.encodeWithSelector(TaxRateBasisPointsOutOfRange.selector, taxRateBasisPoints)
        );
        vm.prank(address(_settlement));
        _staking.setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
    }

    function testSetTaxRateFailWithNonExistentNode() public {
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, dave));
        vm.prank(dave);
        _staking.setTaxRateBasisPoints4Node(1000);
    }

    function testSetTaxRateFailWithPublicGoodNode() public {
        _createPublicGoodNode(dave);

        vm.expectRevert(abi.encodeWithSelector(NodeIsPublicGood.selector, dave));
        vm.prank(dave);
        _staking.setTaxRateBasisPoints4Node(1000);
    }

    function testExitSucceeds() public {
        vm.startPrank(alice);
        // create node and deposit
        _staking.createNode{value: 10_000 ether}("Alice", "Alice's node", uint64(1000), false);
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

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
            // preset node status
            _presetNodeStatus(alice, status[i]);

            NodeStatus expectedStatus =
                status[i] == NodeStatus.Online ? NodeStatus.Exiting : NodeStatus.Exited;
            // exit
            expectEmit();
            emit Events.NodeStatusChanged(alice, status[i], expectedStatus);
            _staking.exit();

            // check new status
            Node memory node = _staking.getNode(alice);
            assertEq(uint256(node.status), uint256(expectedStatus));
        }
        vm.stopPrank();
    }

    function testExitFail() public {
        // case 1: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.exit();

        vm.startPrank(alice);
        _staking.createNode{value: 10_000 ether}("Alice", "Alice's node", uint64(1000), false);

        // case 2: CurStateCantExit
        // node in these status can't initiate exit
        NodeStatus[] memory status =
            array(NodeStatus.Slashing, NodeStatus.Offline, NodeStatus.Exiting, NodeStatus.Exited);
        for (uint256 i = 0; i < status.length; i++) {
            // preset node status
            _presetNodeStatus(alice, status[i]);

            vm.expectRevert(abi.encodeWithSelector(CurStateCantExit.selector, uint256(status[i])));
            _staking.exit();
        }

        vm.stopPrank();
    }

    function testNodeStatus() public {
        _createNode(alice);
        // None
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.None));

        // None -> Registered
        vm.startPrank(alice);
        _staking.deposit{value: Const.MIN_DEPOSIT}();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        // Registered -> Initializing
        _presetNodeStatus(alice, NodeStatus.Online);
        _staking.exit();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exiting));

        // Exited -> Registered
        _presetNodeStatus(alice, NodeStatus.Exited);
        _staking.register();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        vm.stopPrank();
    }

    function testRegisterSucceeds() public {
        // case 1: node is not public good
        _createNode(alice);
        vm.startPrank(alice);
        _staking.deposit{value: 10_000 ether}();

        NodeStatus[] memory status = array(NodeStatus.Exited);
        for (uint256 i = 0; i < status.length; i++) {
            // preset node status
            _presetNodeStatus(alice, status[i]);

            // register
            vm.expectEmit();
            emit Events.NodeStatusChanged(alice, status[i], NodeStatus.Registered);
            _staking.register();

            // check node status
            assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));
        }
        vm.stopPrank();

        // case 2: node is public good
        _createPublicGoodNode(bob);
        assertEq(uint256(_getNodeStatus(bob)), uint256(NodeStatus.Registered));

        vm.startPrank(bob);
        _staking.exit();
        assertEq(uint256(_getNodeStatus(bob)), uint256(NodeStatus.Exited));

        _staking.register();
        assertEq(uint256(_getNodeStatus(bob)), uint256(NodeStatus.Registered));
        vm.stopPrank();
    }

    function testRegisterFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.register();

        _createNode(alice);
        vm.startPrank(alice);

        // case 2: node not in exited status
        NodeStatus[] memory status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Outdated,
            NodeStatus.Online,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed,
            NodeStatus.Exiting
        );
        for (uint256 i = 0; i < status.length; i++) {
            // preset node status
            _presetNodeStatus(alice, status[i]);

            vm.expectRevert(
                abi.encodeWithSelector(NodeNotInExitStatus.selector, uint256(status[i]))
            );
            _staking.register();
        }

        // case 3: node deposit is below minimum
        _presetNodeStatus(alice, NodeStatus.Exited);
        vm.expectRevert(abi.encodeWithSelector(NodeDepositBelowMinimum.selector));
        _staking.register();
        vm.stopPrank();
    }

    function testOnlineSucceeds() public {
        _createNode(alice);

        NodeStatus[] memory status =
            array(NodeStatus.Offline, NodeStatus.Slashed, NodeStatus.Outdated);
        for (uint256 i = 0; i < status.length; i++) {
            // preset node status
            _presetNodeStatus(alice, status[i]);

            // online
            expectEmit();
            emit Events.NodeStatusChanged(alice, status[i], NodeStatus.Online);
            vm.prank(alice);
            _staking.online();

            // check node status
            assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Online));
        }
    }

    function testOnlineFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.online();

        _createNode(alice);

        vm.startPrank(alice);
        // case 2: CurStatusCantOnline
        NodeStatus[] memory status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Online,
            NodeStatus.Slashing,
            NodeStatus.Exiting,
            NodeStatus.Exited
        );
        for (uint256 i = 0; i < status.length; i++) {
            _presetNodeStatus(alice, status[i]);
            console.log("status[i]", uint256(status[i]));
            vm.expectRevert(
                abi.encodeWithSelector(CurStatusCantOnline.selector, uint256(status[i]))
            );
            _staking.online();
        }
        vm.stopPrank();
    }

    function testsetNodeStatusByOperator() public {
        _createNode(alice);
        vm.prank(operatorAccount);
        _staking.setNodeStatusByOperator(array(alice), array(NodeStatus.Registered));
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        vm.prank(operatorAccount);
        _staking.setNodeStatusByOperator(array(alice), array(NodeStatus.Initializing));
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Initializing));
    }

    function testSetNodesStatusSucceeds() public {
        _createNode(alice);
        vm.prank(alice);
        _staking.deposit{value: 10_000 ether}();

        NodeStatus[] memory curStatus = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Outdated,
            NodeStatus.Online,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed,
            NodeStatus.Exiting,
            NodeStatus.Exited
        );

        NodeStatus[] memory newStatus = array(
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Outdated,
            NodeStatus.Online,
            NodeStatus.Offline,
            NodeStatus.Exited
        );
        for (uint256 i = 0; i < curStatus.length; i++) {
            for (uint256 j = 0; j < newStatus.length; j++) {
                _setAndCheckNodeStatus(alice, curStatus[i], newStatus[j]);
            }
        }
    }

    // solhint-disable-next-line function-max-lines
    function testSetNodesStatusFail() public {
        // case 1: caller has no ORACLE_ROLE
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector, address(this), ORACLE_ROLE
            )
        );
        _staking.setNodeStatus(array(alice), array(NodeStatus.Online));

        // case 2: InvalidArrayLength
        vm.expectRevert(abi.encodeWithSelector(InvalidArrayLength.selector));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(array(alice, bob), array(NodeStatus.Online));

        // case 3: StatusNotAllowed

        _createNode(alice);

        // set to these status are not allowed
        NodeStatus[] memory status =
            array(NodeStatus.None, NodeStatus.Slashing, NodeStatus.Slashed, NodeStatus.Exiting);
        for (uint256 i = 0; i < status.length; i++) {
            vm.expectRevert(abi.encodeWithSelector(StatusNotAllowed.selector, uint256(status[i])));
            vm.prank(address(_settlement));
            _staking.setNodeStatus(array(alice), array(status[i]));
        }
    }

    function _setAndCheckNodeStatus(address nodeAddr, NodeStatus curStatus, NodeStatus newStatus)
        internal
    {
        _presetNodeStatus(nodeAddr, curStatus);

        expectEmit();
        emit Events.NodeStatusChanged(nodeAddr, curStatus, newStatus);
        vm.prank(address(_settlement));
        _staking.setNodeStatus(array(nodeAddr), array(newStatus));

        // check status
        assertEq(uint256(_getNodeStatus(nodeAddr)), uint256(newStatus));
    }
}
