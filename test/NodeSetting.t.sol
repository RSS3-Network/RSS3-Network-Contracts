// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {CommonTest} from "test/helpers/CommonTest.sol";
import {Const} from "../src/libraries/Const.sol";
import {Node, NodeStatus} from "../src/libraries/DataTypes.sol";
import {
    NodeNotExists,
    TaxRateBasisPointsTooSmall,
    TaxRateBasisPointsTooLarge,
    PublicGoodNodeTaxNotZero,
    NodeExists,
    NodeIsPublicGood,
    NodeDepositBelowMinimum,
    NodeNotInExitStatus,
    DepositForPublicGoodNode,
    WrongNodeStatus,
    CurStateCantExit
} from "../src/libraries/Errors.sol";
import {Events} from "../src/libraries/Events.sol";

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

    function testSetTaxRate4Node(uint64 taxRateBasisPoints) public {
        vm.assume(taxRateBasisPoints <= Const.DENOMINATOR && taxRateBasisPoints >= Const.MIN_TAX_RATE_BASIS_POINTS);

        _createNode(alice);

        vm.startPrank(alice);
        expectEmit();
        emit Events.NodeTaxRateBasisPointsSet(alice, taxRateBasisPoints);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);
        vm.stopPrank();

        Node memory node = _staking.getNode(alice);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
    }

    function testSetTaxRate4PublicPool(uint64 expectedTaxRateBasisPoints) public {
        vm.assume(expectedTaxRateBasisPoints <= Const.DENOMINATOR);

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
        vm.assume(taxRateBasisPoints > Const.DENOMINATOR);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
        vm.prank(alice);
        _staking.setTaxRateBasisPoints4Node(taxRateBasisPoints);

        vm.expectRevert(abi.encodeWithSelector(TaxRateBasisPointsTooLarge.selector));
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

    function testNodeStatus() public {
        _disableAlphaPhase();
        uint256 amount = 10000 ether;

        _createNode(alice);

        // none
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.None));

        vm.startPrank(alice);
        _staking.deposit{value: amount}();

        // registered
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        _presetNodeStatus(alice, NodeStatus.Online);

        // exiting
        _staking.exit();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exiting));

        // exited
        skip(Const.NODE_EXIT_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));

        // registered
        _staking.register();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        vm.stopPrank();
    }

    function testNodeExitedStatus() public {
        // case 1: Registered -> Exited
        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: 10000 ether}();
        _staking.exit();
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));

        // case 2: Online -> Exiting -> Exited
        _presetNodeStatus(alice, NodeStatus.Online);
        _staking.exit();

        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exiting));

        skip(Const.NODE_EXIT_PERIOD);
        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));

        vm.stopPrank();
    }

    function testRegisterSucceeds() public {
        _createNode(alice);

        vm.startPrank(alice);
        _staking.deposit{value: 10000 ether}();

        _staking.exit();

        // register
        vm.expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Exited, NodeStatus.Registered);
        _staking.register();
        vm.stopPrank();

        // check node status
        NodeStatus status = _getNodeStatus(alice);
        assertEq(uint256(status), uint256(NodeStatus.Registered));
    }

    function testRegisterFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.register();

        _createNode(alice);
        vm.startPrank(alice);

        // case 2: node not in exit status
        vm.expectRevert(abi.encodeWithSelector(NodeNotInExitStatus.selector));
        _staking.register();

        // case 3: node deposit is below minimum
        _presetNodeStatus(alice, NodeStatus.Exiting);
        vm.expectRevert(abi.encodeWithSelector(NodeDepositBelowMinimum.selector));
        _staking.register();
        vm.stopPrank();
    }

    function testOnlineSucceeds() public {
        _createNode(alice);
        _presetNodeStatus(alice, NodeStatus.Offline);

        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Offline, NodeStatus.Online);
        vm.prank(alice);
        _staking.online();

        // check node status
        NodeStatus status = _getNodeStatus(alice);
        assertEq(uint256(status), uint256(NodeStatus.Online));
    }

    function testOnlineFail() public {
        // case 1: node not exists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.online();

        _createNode(alice);

        vm.startPrank(alice);
        // case 2: wrong node status
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
                abi.encodeWithSelector(WrongNodeStatus.selector, uint256(status[i]), uint256(NodeStatus.Online))
            );
            _staking.online();
        }
        vm.stopPrank();
    }

    function testExitSucceeds() public {
        vm.prank(alice);
        _staking.createNode{value: 10000 ether}("Alice", "Alice's node", uint64(1000), false);

        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Registered));

        expectEmit();
        emit Events.NodeStatusChanged(alice, NodeStatus.Registered, NodeStatus.Exited);
        vm.prank(alice);
        _staking.exit();

        assertEq(uint256(_getNodeStatus(alice)), uint256(NodeStatus.Exited));
    }

    function testExitFail() public {
        // case 1: NodeNotExists
        vm.expectRevert(abi.encodeWithSelector(NodeNotExists.selector, address(this)));
        _staking.exit();

        vm.startPrank(alice);
        _staking.createNode{value: 10000 ether}("Alice", "Alice's node", uint64(1000), false);

        // case 2: CurStateCantExit Slashing -> Exiting
        _presetNodeStatus(alice, NodeStatus.Slashing);
        vm.expectRevert(abi.encodeWithSelector(CurStateCantExit.selector, uint256(NodeStatus.Slashing)));
        _staking.exit();

        // TODO: Offline -> Exiting is not allowed ???
        // case 4: CurStateCantExit Offline -> Exiting
        _presetNodeStatus(alice, NodeStatus.Offline);
        vm.expectRevert(abi.encodeWithSelector(CurStateCantExit.selector, uint256(NodeStatus.Offline)));
        _staking.exit();

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

        // WrongNodeStatus
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

    function _invalidNodeStatusTransition(address nodeAddr, NodeStatus curStatus, NodeStatus newStatus) internal {
        _presetNodeStatus(nodeAddr, curStatus);

        vm.expectRevert(abi.encodeWithSelector(WrongNodeStatus.selector, uint256(curStatus), uint256(newStatus)));
        vm.prank(address(_settlement));
        _staking.setNodeStatus(array(nodeAddr), array(newStatus));
    }

    function _setAndCheckNodeStatus(address nodeAddr, NodeStatus curStatus, NodeStatus newStatus) internal {
        _presetNodeStatus(nodeAddr, curStatus);

        expectEmit();
        emit Events.NodeStatusChanged(nodeAddr, curStatus, newStatus);
        vm.prank(address(_settlement));
        _staking.setNodeStatus(array(nodeAddr), array(newStatus));

        // check status
        assertEq(uint256(_getNodeStatus(nodeAddr)), uint256(newStatus));
    }
}
