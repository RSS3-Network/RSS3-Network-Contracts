// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {Const} from "../src/libraries/Const.sol";
import {Node, NodeStatus} from "../src/libraries/DataTypes.sol";
import {
    CurStateCantExit,
    CurStatusCantOnline,
    DepositForPublicGoodNode,
    InvalidNodeStatusTransition,
    NodeDepositBelowMinimum,
    NodeExists,
    NodeIsPublicGood,
    NodeNotExists,
    NodeNotInExitStatus,
    PublicGoodNodeTaxNotZero,
    TaxRateBasisPointsOutOfRange
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";
import {CommonTest} from "./helpers/CommonTest.sol";

contract NodeSettingTest is CommonTest {
    function setUp() public {
        _setUp();

        vm.deal(alice, _initialAmount);
        vm.deal(bob, _initialAmount);
        vm.deal(carol, _initialAmount);
        vm.deal(dave, _initialAmount);

        vm.deal(address(_settlement), 30000000 ether);
    }

    function testCreateNode(uint64 taxRateBasisPoints) public {
        taxRateBasisPoints =
            uint64(bound(taxRateBasisPoints, Const.MIN_TAX_RATE_BASIS_POINTS, 10000));

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
        taxRateBasisPoints =
            uint64(bound(taxRateBasisPoints, Const.MIN_TAX_RATE_BASIS_POINTS, 10000));
        amount = bound(amount, 1, _initialAmount);

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
        vm.assume(taxRateBasisPoints > 10000 || taxRateBasisPoints < 500);

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
        _staking.createNode{value: 10000 ether}("Alice", "Alice's node", uint64(1000), false);
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

            // check exit time if node is in Exiting status
            if (node.status == NodeStatus.Exiting) {
                assertEq(node.exitTime, block.timestamp + Const.NODE_EXIT_PERIOD);

                // skip the exit period, node should be in Exited status
                skip(Const.NODE_EXIT_PERIOD);
                assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));
            }
        }
        vm.stopPrank();
    }

    function testExitFail() public {
        // case 1: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.exit();

        vm.startPrank(alice);
        _staking.createNode{value: 10000 ether}("Alice", "Alice's node", uint64(1000), false);

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

        // Exiting -> Exited
        skip(Const.NODE_EXIT_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));

        // Exited -> Registered
        _staking.register();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        vm.stopPrank();
    }

    function testRegisterSucceeds() public {
        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: 10000 ether}();

        NodeStatus[] memory status = array(NodeStatus.Exiting, NodeStatus.Exited);
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
    }

    function testRegisterFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.register();

        _createNode(alice);
        vm.startPrank(alice);

        // case 2: node not in exit status
        NodeStatus[] memory status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Outdated,
            NodeStatus.Online,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed
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
        _presetNodeStatus(alice, NodeStatus.Exiting);
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
            vm.expectRevert(
                abi.encodeWithSelector(CurStatusCantOnline.selector, uint256(status[i]))
            );
            _staking.online();
        }
        vm.stopPrank();
    }

    function testSetNodesStatusSucceeds() public {
        _createNode(alice);
        vm.prank(alice);
        _staking.deposit{value: 10000 ether}();

        // Online -> Offline
        _setAndCheckNodeStatus(alice, NodeStatus.Online, NodeStatus.Offline);
        // Exiting -> Offline
        _setAndCheckNodeStatus(alice, NodeStatus.Exiting, NodeStatus.Offline);

        // Registered -> Initializing
        _setAndCheckNodeStatus(alice, NodeStatus.Registered, NodeStatus.Initializing);

        //  Initializing -> Online
        _setAndCheckNodeStatus(alice, NodeStatus.Initializing, NodeStatus.Online);
        // Offline -> Online
        _setAndCheckNodeStatus(alice, NodeStatus.Offline, NodeStatus.Online);
        // Slashed -> Online
        _setAndCheckNodeStatus(alice, NodeStatus.Slashed, NodeStatus.Online);
        // Outdated -> Online
        _setAndCheckNodeStatus(alice, NodeStatus.Outdated, NodeStatus.Online);

        // Initializing -> Outdated
        _setAndCheckNodeStatus(alice, NodeStatus.Initializing, NodeStatus.Outdated);

        // Registered -> Initializing
        _setAndCheckNodeStatus(alice, NodeStatus.Registered, NodeStatus.Initializing);
    }

    // solhint-disable-next-line function-max-lines
    function testSetNodesStatusFail() public {
        _createNode(alice);

        // InvalidNodeStatusTransition
        // transitions to these status are not allowed by the `setNodeStatus`
        NodeStatus[] memory status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed,
            NodeStatus.Exiting,
            NodeStatus.Exited
        );
        for (uint256 i = 0; i < status.length; i++) {
            _invalidNodeStatusTransition(alice, NodeStatus.None, status[i]);
        }

        // -> Initializing
        // these status can't be set to Initializing
        status = array(
            NodeStatus.None,
            NodeStatus.Initializing,
            NodeStatus.Online,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed,
            NodeStatus.Exiting,
            NodeStatus.Exited,
            NodeStatus.Outdated
        );
        for (uint256 i = 0; i < status.length; i++) {
            _invalidNodeStatusTransition(alice, status[i], NodeStatus.Initializing);
        }

        // -> Online
        // these status can't be set to Online
        status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Online,
            NodeStatus.Slashing,
            NodeStatus.Exiting,
            NodeStatus.Exited
        );
        for (uint256 i = 0; i < status.length; i++) {
            _invalidNodeStatusTransition(alice, status[i], NodeStatus.Online);
        }

        // -> Offline
        // these status can't be set to Offline
        status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Initializing,
            NodeStatus.Outdated,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed,
            NodeStatus.Exited
        );
        for (uint256 i = 0; i < status.length; i++) {
            _invalidNodeStatusTransition(alice, status[i], NodeStatus.Offline);
        }

        // -> Outdated
        // these status can't be set to Outdated
        status = array(
            NodeStatus.None,
            NodeStatus.Registered,
            NodeStatus.Outdated,
            NodeStatus.Online,
            NodeStatus.Offline,
            NodeStatus.Slashing,
            NodeStatus.Slashed,
            NodeStatus.Exited,
            NodeStatus.Outdated
        );
        for (uint256 i = 0; i < status.length; i++) {
            _invalidNodeStatusTransition(alice, status[i], NodeStatus.Outdated);
        }
    }

    function _invalidNodeStatusTransition(
        address nodeAddr,
        NodeStatus curStatus,
        NodeStatus newStatus
    ) internal {
        _presetNodeStatus(nodeAddr, curStatus);

        vm.expectRevert(
            abi.encodeWithSelector(
                InvalidNodeStatusTransition.selector, uint256(curStatus), uint256(newStatus)
            )
        );
        vm.prank(address(_settlement));
        _staking.setNodeStatus(array(nodeAddr), array(newStatus));
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
