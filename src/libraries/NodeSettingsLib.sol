// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,var-name-mixedcase
pragma solidity 0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Const} from "./Const.sol";
import {Node, NodeStatus} from "./DataTypes.sol";
import {
    CreateNodeToZeroAddress,
    NodeExists,
    NodeIsPublicGood,
    NodeNotExists,
    NodeInExitStatus,
    CurStateCantExit,
    NodeNotInExitStatus,
    WrongNodeStatus,
    InvalidArrayLength,
    TaxRateBasisPointsTooLarge,
    PublicGoodNodeTaxNotZero,
    TaxRateBasisPointsTooSmall,
    NodeDepositBelowMinimum
} from "./Errors.sol";
import {Events} from "./Events.sol";
import {StorageLib} from "./StorageLib.sol";

library NodeSettingsLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints, address nodeAddr) external {
        _validateTaxRateBasisPoints(taxRateBasisPoints);

        Node storage node = StorageLib.getNode(nodeAddr);

        _validateNodeAddress(node.account);

        if (node.publicGood) revert NodeIsPublicGood();

        node.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.NodeTaxRateBasisPointsSet(nodeAddr, taxRateBasisPoints);
    }

    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external {
        if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();

        Node storage publicPool = StorageLib.publicPool();

        publicPool.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.PublicPoolTaxRateBasisPointsSet(taxRateBasisPoints);
    }

    function updateNode(address nodeAddr, string calldata name, string calldata description) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        _validateNodeAddress(node.account);

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
        if (nodeAddr == address(0)) revert CreateNodeToZeroAddress();
        if (publicGood) {
            if (taxRateBasisPoints > 0) revert PublicGoodNodeTaxNotZero();
        } else {
            if (taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();
            if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();
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

        emit Events.NodeCreated(nodeId, nodeAddr, name, description, taxRateBasisPoints, publicGood, isAlphaPhase);
    }

    function exit(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        _validateNodeAddress(node.account);

        // validate node exit status
        NodeStatus curStatus = _getNodeStatus(node);
        if (
            curStatus == NodeStatus.Registered ||
            curStatus == NodeStatus.Initializing ||
            curStatus == NodeStatus.Slashed
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

    function register(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        _validateNodeAddress(node.account);

        NodeStatus curStatus = _getNodeStatus(node);
        // check if the node is in exit status
        if (NodeStatus.Exiting != curStatus && NodeStatus.Exited != curStatus) revert NodeNotInExitStatus();

        uint256 operationPoolTokens = StorageLib.getNode(nodeAddr).operationPoolTokens;
        if (operationPoolTokens < Const.MIN_DEPOSIT) revert NodeDepositBelowMinimum();

        // set node status
        node.status = NodeStatus.Registered;

        emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Registered);
    }

    function online(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);
        _validateNodeAddress(node.account);

        NodeStatus curStatus = _getNodeStatus(node);
        if (NodeStatus.Offline != curStatus && NodeStatus.Slashed != curStatus && NodeStatus.Outdated != curStatus)
            revert WrongNodeStatus(uint256(curStatus), uint256(NodeStatus.Online));

        // set node status
        node.status = NodeStatus.Online;

        emit Events.NodeStatusChanged(nodeAddr, curStatus, NodeStatus.Online);
    }

    function setNodesStatus(address[] calldata nodeAddrs, NodeStatus[] calldata status) external {
        if (nodeAddrs.length != status.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            _setNodeStatus(nodeAddrs[i], status[i]);
        }
    }

    function getNodeStatus(Node calldata node) external view returns (NodeStatus) {
        return _getNodeStatus(node);
    }

    function _setNodeStatus(address nodeAddr, NodeStatus newStatus) internal {
        Node storage node = StorageLib.getNode(nodeAddr);
        NodeStatus curStatus = _getNodeStatus(node);

        if (!_isValidTransition(curStatus, newStatus)) revert WrongNodeStatus(uint256(curStatus), uint256(newStatus));

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

    function _validateNodeNotInExitStatus(Node storage node) internal view {
        NodeStatus status = _getNodeStatus(node);
        if (NodeStatus.Exiting == status || NodeStatus.Exited == status) revert NodeInExitStatus();
    }

    function _validateTaxRateBasisPoints(uint64 taxRateBasisPoints) internal pure {
        if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();

        if (taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();
    }

    function _validateNodeAddress(address nodeAddr) internal pure {
        if (nodeAddr == address(0)) revert NodeNotExists();
    }

    /// @dev check that the status transition from curStatus -> newStatus is valid
    function _isValidTransition(NodeStatus curStatus, NodeStatus newStatus) internal pure returns (bool) {
        // validate that the curStatus must in the validCurStatus
        NodeStatus[] memory validCurStatus = _getValidTransitions(newStatus);
        for (uint256 i = 0; i < validCurStatus.length; i++) {
            if (validCurStatus[i] == curStatus) {
                return true;
            }
        }
        return false;
    }

    function _getValidTransitions(NodeStatus newStatus) internal pure returns (NodeStatus[] memory) {
        if (newStatus == NodeStatus.Offline) {
            NodeStatus[] memory validTransitions = new NodeStatus[](2);
            validTransitions[0] = NodeStatus.Online;
            validTransitions[1] = NodeStatus.Exiting;
            return validTransitions;
        } else if (newStatus == NodeStatus.Online) {
            NodeStatus[] memory validTransitions = new NodeStatus[](4);
            validTransitions[0] = NodeStatus.Initializing;
            validTransitions[1] = NodeStatus.Offline;
            validTransitions[2] = NodeStatus.Slashed;
            validTransitions[3] = NodeStatus.Outdated;
            return validTransitions;
        } else if (newStatus == NodeStatus.Outdated) {
            NodeStatus[] memory validTransitions = new NodeStatus[](1);
            validTransitions[0] = NodeStatus.Initializing;
            return validTransitions;
        } else if (newStatus == NodeStatus.Initializing) {
            NodeStatus[] memory validTransitions = new NodeStatus[](1);
            validTransitions[0] = NodeStatus.Registered;
            return validTransitions;
        } else {
            return new NodeStatus[](0);
        }
    }
}
