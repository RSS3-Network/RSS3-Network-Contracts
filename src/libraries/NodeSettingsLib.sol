// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,var-name-mixedcase
pragma solidity 0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Const} from "./Const.sol";
import {DataTypes} from "./DataTypes.sol";
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

        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

        _validateNodeAddress(node.account);

        if (node.publicGood) revert NodeIsPublicGood();

        node.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.NodeTaxRateBasisPointsSet(nodeAddr, taxRateBasisPoints);
    }

    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external {
        if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();

        DataTypes.Node storage publicPool = StorageLib.publicPool();

        publicPool.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.PublicPoolTaxRateBasisPointsSet(taxRateBasisPoints);
    }

    function updateNode(address nodeAddr, string calldata name, string calldata description) external {
        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);
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

        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);
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
        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

        _validateNodeAddress(node.account);

        // validate node exit status
        _validateNodeNotInExitStatus(node);

        // update node time
        node.exitingTime = block.timestamp;
        // set node status
        node.status = DataTypes.NodeStatus.Exiting;

        emit Events.NodeExitRequested(nodeAddr);
    }

    function reRegister(address nodeAddr) external {
        DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

        _validateNodeAddress(node.account);

        _validateNodeInExitStatus(node);

        uint256 opPoolTokens = StorageLib.getNode(nodeAddr).operationPoolTokens;
        if (opPoolTokens < Const.MIN_DEPOSIT) revert NodeDepositBelowMinimum();

        // update node time
        node.registerTime = block.timestamp;
        delete node.offlineTime;
        delete node.exitingTime;
        // set node status
        node.status = DataTypes.NodeStatus.Registered;

        emit Events.NodeReentryRequested(nodeAddr);
    }

    function setNodesStatus(address[] calldata nodeAddrs, DataTypes.NodeStatus[] calldata status) external {
        if (nodeAddrs.length != status.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];
            DataTypes.NodeStatus s = status[i];

            DataTypes.Node storage node = StorageLib.getNode(nodeAddr);

            // can only set node status as: Online, Offline and Initializing
            if (s == DataTypes.NodeStatus.Initializing || s == DataTypes.NodeStatus.Online) {
                node.status = s;

                delete node.registerTime;
                delete node.offlineTime;
            } else if (s == DataTypes.NodeStatus.Offline) {
                node.status = s;
                node.offlineTime = block.timestamp;
            } else {
                revert WrongNodeStatus(uint256(s));
            }
        }

        emit Events.NodeStatusSet(nodeAddrs, status);
    }

    function getNodeStatus(DataTypes.Node calldata node) external view returns (DataTypes.NodeStatus) {
        return _getNodeStatus(node);
    }

    function _getNodeStatus(DataTypes.Node memory node) internal view returns (DataTypes.NodeStatus) {
        DataTypes.NodeStatus status = node.status;

        // Registered Node transitions to Exited state after 30 Epochs of inactivity.
        if (status == DataTypes.NodeStatus.Registered) {
            if (node.registerTime + Const.NODE_INACTIVITY_PERIOD <= block.timestamp) {
                status = DataTypes.NodeStatus.Exited;
                return status;
            }
        }

        // An Offline Node transitions to Exited state after 30 Epochs of inactivity.
        if (status == DataTypes.NodeStatus.Offline) {
            if (node.offlineTime + Const.NODE_INACTIVITY_PERIOD <= block.timestamp) {
                status = DataTypes.NodeStatus.Exited;
                return status;
            }
        }

        // An Exiting Node transitions to Exited state after 1 Epoch.
        if (status == DataTypes.NodeStatus.Exiting) {
            if (node.exitingTime + Const.NODE_EXIT_PERIOD <= block.timestamp) {
                status = DataTypes.NodeStatus.Exited;
                return status;
            }
        }

        return status;
    }

    function _validateNodeNotInExitStatus(DataTypes.Node storage node) internal view {
        DataTypes.NodeStatus status = _getNodeStatus(node);
        if (DataTypes.NodeStatus.Exiting == status || DataTypes.NodeStatus.Exited == status) revert NodeInExitStatus();
    }

    function _validateTaxRateBasisPoints(uint64 taxRateBasisPoints) internal pure {
        if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();
        if (taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();
    }

    function _validateNodeInExitStatus(DataTypes.Node storage node) internal view {
        DataTypes.NodeStatus status = _getNodeStatus(node);
        if (DataTypes.NodeStatus.Exiting != status && DataTypes.NodeStatus.Exited != status)
            revert NodeNotInExitStatus();
    }

    function _validateNodeAddress(address nodeAddr) internal pure {
        if (nodeAddr == address(0)) revert NodeNotExists();
    }
}
