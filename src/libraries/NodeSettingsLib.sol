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

    function requestExit(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);

        _validateNodeAddress(node.account);

        // validate node exit status
        _validateNodeNotInExitStatus(node);

        // update node time
        node.exitingTime = block.timestamp;
        // set node status
        node.status = NodeStatus.Exiting;

        emit Events.NodeExitRequested(nodeAddr);
    }

    function reRegister(address nodeAddr) external {
        Node storage node = StorageLib.getNode(nodeAddr);

        _validateNodeAddress(node.account);

        _validateNodeInExitStatus(node);

        uint256 opPoolTokens = StorageLib.getNode(nodeAddr).operationPoolTokens;
        if (opPoolTokens < Const.MIN_DEPOSIT) revert NodeDepositBelowMinimum();

        // update node time
        node.registerTime = block.timestamp;
        delete node.offlineTime;
        delete node.exitingTime;
        delete node.slashedTime;
        // set node status
        node.status = NodeStatus.Registered;

        emit Events.NodeReentryRequested(nodeAddr);
    }

    function setNodesStatus(address[] calldata nodeAddrs, NodeStatus[] calldata status) external {
        if (nodeAddrs.length != status.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            _setNodeStatus(nodeAddrs[i], status[i]);
        }

        emit Events.NodeStatusSet(nodeAddrs, status);
    }

    function getNodeStatus(Node calldata node) external view returns (NodeStatus) {
        return _getNodeStatus(node);
    }

    function _setNodeStatus(address nodeAddr, NodeStatus newStatus) internal {
        Node storage node = StorageLib.getNode(nodeAddr);
        NodeStatus curStatus = _getNodeStatus(node);

        // can only set node status as: Online, Offline and Initializing
        if (newStatus == NodeStatus.Initializing) {
            if (curStatus != NodeStatus.Registered) revert WrongNodeStatus(uint256(curStatus), uint256(newStatus));
            node.status = newStatus;

            delete node.registerTime;
            delete node.offlineTime;
            delete node.slashedTime;
        } else if (newStatus == NodeStatus.Online) {
            if (
                curStatus != NodeStatus.Initializing &&
                curStatus != NodeStatus.Offline &&
                curStatus != NodeStatus.Slashed
            ) revert WrongNodeStatus(uint256(curStatus), uint256(newStatus));
            node.status = newStatus;

            delete node.registerTime;
            delete node.offlineTime;
            delete node.slashedTime;
        } else if (newStatus == NodeStatus.Offline) {
            node.status = newStatus;
            node.offlineTime = block.timestamp;
        } else {
            revert WrongNodeStatus(uint256(curStatus), uint256(newStatus));
        }
    }

    function _getNodeStatus(Node memory node) internal view returns (NodeStatus) {
        NodeStatus status = node.status;

        // Registered Node transitions to Exited state after 30 Epochs of inactivity.
        if (status == NodeStatus.Registered && _inactive(node.registerTime, Const.NODE_INACTIVITY_PERIOD)) {
            status = NodeStatus.Exited;
            return status;
        }

        // An Offline Node transitions to Exited state after 30 Epochs of inactivity.
        if (status == NodeStatus.Offline && _inactive(node.offlineTime, Const.NODE_INACTIVITY_PERIOD)) {
            status = NodeStatus.Exited;
            return status;
        }

        // An Exiting Node transitions to Exited state after 1 Epoch.
        if (status == NodeStatus.Exiting && _inactive(node.exitingTime, Const.NODE_EXIT_PERIOD)) {
            status = NodeStatus.Exited;
            return status;
        }

        // An Slashed Node transitions to Offline state after 30 Epochs of inactivity.
        if (status == NodeStatus.Slashed && _inactive(node.slashedTime, Const.NODE_OFFLINE_PERIOD)) {
            status = NodeStatus.Offline;
            return status;
        }

        return status;
    }

    function _validateNodeNotInExitStatus(Node storage node) internal view {
        NodeStatus status = _getNodeStatus(node);
        if (NodeStatus.Exiting == status || NodeStatus.Exited == status) revert NodeInExitStatus();
    }

    function _validateNodeInExitStatus(Node storage node) internal view {
        NodeStatus status = _getNodeStatus(node);
        if (NodeStatus.Exiting != status && NodeStatus.Exited != status) revert NodeNotInExitStatus();
    }

    function _inactive(uint256 time, uint256 duration) internal view returns (bool) {
        return time + duration <= block.timestamp;
    }

    function _validateTaxRateBasisPoints(uint64 taxRateBasisPoints) internal pure {
        if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();

        if (taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();
    }

    function _validateNodeAddress(address nodeAddr) internal pure {
        if (nodeAddr == address(0)) revert NodeNotExists();
    }
}
