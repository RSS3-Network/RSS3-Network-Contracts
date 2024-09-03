// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,var-name-mixedcase
pragma solidity 0.8.20;

import {Const} from "./Const.sol";
import {Node, NodeStatus} from "./DataTypes.sol";
import {
    CurStateCantExit,
    CurStatusCantOnline,
    InvalidArrayLength,
    InvalidArrayLength,
    InvalidNodeStatusTransition,
    InvalidNodeStatusTransition,
    NodeDepositBelowMinimum,
    NodeDepositBelowMinimum,
    NodeExists,
    NodeInExitStatus,
    NodeIsPublicGood,
    NodeNotExists,
    NodeNotInExitStatus,
    PublicGoodNodeTaxNotZero,
    PublicGoodNodeTaxNotZero,
    TaxRateBasisPointsOutOfRange
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {StorageLib} from "./StorageLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library NodeSettingsLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints, address nodeAddr) external {
        _validateTaxRateBasisPoints(taxRateBasisPoints);

        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists(nodeAddr);
        if (node.publicGood) revert NodeIsPublicGood(nodeAddr);

        node.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.NodeTaxRateBasisPointsSet(nodeAddr, taxRateBasisPoints);
    }

    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external {
        _validateTaxRateBasisPoints(taxRateBasisPoints);

        Node storage publicPool = StorageLib.publicPool();
        publicPool.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.PublicPoolTaxRateBasisPointsSet(taxRateBasisPoints);
    }

    function updateNode(address nodeAddr, string calldata name, string calldata description)
        external
    {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists(nodeAddr);

        node.name = name;
        node.description = description;

        emit Events.NodeUpdated(nodeAddr, name, description);
    }

    /// @dev create a node
    function createNode(
        address nodeAddr,
        string calldata name,
        string calldata description,
        uint64 taxRateBasisPoints,
        bool publicGood
    ) external {
        if (publicGood) {
            if (taxRateBasisPoints > 0) revert PublicGoodNodeTaxNotZero();
        } else {
            _validateTaxRateBasisPoints(taxRateBasisPoints);
        }

        uint256 nodeId = StorageLib.nextNodeId();
        bool isAlphaPhase = StorageLib.getIsAlphaPhase();

        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.nodeId > 0) revert NodeExists();
        node.nodeId = nodeId;
        node.account = nodeAddr;
        node.name = name;
        node.description = description;
        node.taxRateBasisPoints = taxRateBasisPoints;
        node.publicGood = publicGood;
        node.alpha = isAlphaPhase;

        // add to node list
        StorageLib.nodeAddrs().add(nodeAddr);

        emit Events.NodeCreated(
            nodeId, nodeAddr, name, description, taxRateBasisPoints, publicGood, isAlphaPhase
        );
    }

    /**
     * @notice Allows a node to exit from the network.
     * @dev The node must be in a valid state to exit.
     * If the node is registered, initializing, or slashed, its status will be set to "Exited".
     * If the node is online, its status will be set to "Exiting",
     * and the exit time will be set to the current block timestamp plus the node exit period.
     * If the node is in any other state, a revert will occur with the corresponding error message.
     * @param nodeAddr The address of the node to exit.
     */
    function exit(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists(nodeAddr);

        // validate node exit status
        NodeStatus curStatus = _getNodeStatus(node);
        if (
            curStatus == NodeStatus.None || curStatus == NodeStatus.Registered
                || curStatus == NodeStatus.Initializing || curStatus == NodeStatus.Outdated
                || curStatus == NodeStatus.Slashed
        ) {
            node.status = NodeStatus.Exited;
        } else if (curStatus == NodeStatus.Online) {
            node.status = NodeStatus.Exiting;
            node.exitTime = block.timestamp + Const.NODE_EXIT_PERIOD;
        } else {
            revert CurStateCantExit(uint256(curStatus));
        }

        emit Events.NodeStatusChanged(nodeAddr, curStatus, node.status);
    }

    /**
     * @notice Register a node that has exited or is in the process of exiting.
     * @dev The node must be in "Exiting" or "Exited" status and have a sufficient deposit amount.
     * @param nodeAddr The address of the node to be registered.
     */
    function register(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists(nodeAddr);

        NodeStatus curStatus = _getNodeStatus(node);
        // throws a `NodeNotInExitStatus` error if the node is not in "Exiting" or "Exited" status.
        if (NodeStatus.Exiting != curStatus && NodeStatus.Exited != curStatus) {
            revert NodeNotInExitStatus(uint256(curStatus));
        }

        // check if the node's operation pool tokens are below the minimum deposit amount.
        uint256 operationPoolTokens = StorageLib.getNode(nodeAddr).operationPoolTokens;
        if (operationPoolTokens < Const.MIN_DEPOSIT) revert NodeDepositBelowMinimum();

        // set node status
        node.status = NodeStatus.Registered;

        emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Registered);
    }

    /**
     * @notice Transition a node to online status.
     * @param nodeAddr The address of the node to transition.
     */
    function online(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists(nodeAddr);

        // if the current status is not Offline, Slashed, or Outdated, it reverts with an error
        NodeStatus curStatus = _getNodeStatus(node);
        if (
            NodeStatus.Offline != curStatus && NodeStatus.Slashed != curStatus
                && NodeStatus.Outdated != curStatus
        ) {
            revert CurStatusCantOnline(uint256(curStatus));
        }

        // set node status
        node.status = NodeStatus.Online;

        emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Online);
    }

    /**
     * @dev Sets the status of multiple nodes.
     * @param nodeAddrs The addresses of the nodes.
     * @param status The corresponding status of the nodes.
     */
    function setNodesStatus(address[] calldata nodeAddrs, NodeStatus[] calldata status) external {
        if (nodeAddrs.length != status.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            _setNodeStatus(nodeAddrs[i], status[i]);
        }
    }

    /**
     * @dev Returns the status of a node.
     * @param node The node to get the status of.
     * @return The status of the node.
     */
    function getNodeStatus(Node calldata node) external view returns (NodeStatus) {
        return _getNodeStatus(node);
    }

    /**
     * @dev Retrieves the information of multiple nodes.
     * @param nodeAddrs The addresses of the nodes to retrieve information for.
     * @return nodes An array of Node structs containing the information of the nodes.
     */
    function getNodes(address[] calldata nodeAddrs) external view returns (Node[] memory nodes) {
        nodes = new Node[](nodeAddrs.length);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];

            nodes[i] = StorageLib.getNode(nodeAddr);
            nodes[i].status = _getNodeStatus(nodes[i]);
        }
    }

    /**
     * @dev Sets the status of a node.
     * @param nodeAddr The address of the node to update.
     * @param newStatus The new status to set for the node.
     */
    function _setNodeStatus(address nodeAddr, NodeStatus newStatus) internal {
        Node storage node = StorageLib.getNode(nodeAddr);
        NodeStatus curStatus = _getNodeStatus(node);

        // throws a `InvalidNodeStatusTransition` error if the transition is invalid.
        if (!_isValidTransition(curStatus, newStatus)) {
            revert InvalidNodeStatusTransition(uint256(curStatus), uint256(newStatus));
        }

        node.status = newStatus;
        emit Events.NodeStatusChanged(nodeAddr, curStatus, newStatus);
    }

    function _getNodeStatus(Node memory node) internal view returns (NodeStatus) {
        NodeStatus status = node.status;

        // An Exiting Node transitions to Exited state after 1 Epoch.
        if (status == NodeStatus.Exiting && node.exitTime <= block.timestamp) {
            status = NodeStatus.Exited;
        }

        return status;
    }

    /**
     * @dev Validates that a node is not in an exit status (Exiting or Exited).
     * @param nodeAddr The address of the node to validate.
     */
    function _validateNodeNotInExitStatus(address nodeAddr) internal view {
        Node storage node = StorageLib.getNode(nodeAddr);
        NodeStatus status = _getNodeStatus(node);
        if (NodeStatus.Exiting == status || NodeStatus.Exited == status) revert NodeInExitStatus();
    }

    /**
     * @dev Validates the tax rate basis points.
     * @param taxRateBasisPoints The tax rate basis points to validate.
     * @dev Throws an exception if the tax rate basis points are too large or too small.
     */
    function _validateTaxRateBasisPoints(uint64 taxRateBasisPoints) internal pure {
        if (
            taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS
                || taxRateBasisPoints > Const.DENOMINATOR
        ) {
            revert TaxRateBasisPointsOutOfRange(taxRateBasisPoints);
        }
    }

    /**
     * @dev Checks if a transition from curStatus -> newStatus is valid.
     * @param curStatus The current node status.
     * @param newStatus The new node status.
     * @return A boolean indicating whether the transition is valid or not.
     */
    function _isValidTransition(NodeStatus curStatus, NodeStatus newStatus)
        internal
        pure
        returns (bool)
    {
        // validate that the curStatus must in the validCurStatus
        NodeStatus[] memory validCurStatus = _getValidTransitions(newStatus);
        for (uint256 i = 0; i < validCurStatus.length; i++) {
            if (validCurStatus[i] == curStatus) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Returns an array of valid transitions for a given `newStatus`.
     * @param newStatus The new status to check valid transitions for.
     * @return validTransitions An array of valid transitions for the given `newStatus`.
     */
    function _getValidTransitions(NodeStatus newStatus)
        internal
        pure
        returns (NodeStatus[] memory validTransitions)
    {
        if (newStatus == NodeStatus.Offline) {
            validTransitions = new NodeStatus[](2);
            validTransitions[0] = NodeStatus.Online;
            validTransitions[1] = NodeStatus.Exiting;
        } else if (newStatus == NodeStatus.Online) {
            validTransitions = new NodeStatus[](4);
            validTransitions[0] = NodeStatus.Initializing;
            validTransitions[1] = NodeStatus.Offline;
            validTransitions[2] = NodeStatus.Slashed;
            validTransitions[3] = NodeStatus.Outdated;
        } else if (newStatus == NodeStatus.Outdated) {
            validTransitions = new NodeStatus[](1);
            validTransitions[0] = NodeStatus.Initializing;
        } else if (newStatus == NodeStatus.Initializing) {
            validTransitions = new NodeStatus[](1);
            validTransitions[0] = NodeStatus.Registered;
        } else {
            validTransitions = new NodeStatus[](0);
        }
        return validTransitions;
    }
}
