// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,var-name-mixedcase
pragma solidity 0.8.20;
import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";
import {StorageLib} from "./StorageLib.sol";
import {Const} from "./Const.sol";
import {
    CreateNodeToZeroAddress,
    NodeExists,
    NodeIsPublicGood,
    NodeNotExists,
    WrongNodeStatus,
    InvalidArrayLength,
    TaxRateBasisPointsTooLarge,
    PublicGoodNodeTaxNotZero,
    TaxRateBasisPointsTooSmall
} from "./Errors.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

library NodeSettingsLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints, address nodeAddr) external {
        _validateTaxRateBasisPoints(taxRateBasisPoints);

        DataTypes.Node storage node = StorageLib.nodes()[nodeAddr];

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
        DataTypes.Node storage node = StorageLib.nodes()[nodeAddr];
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

        DataTypes.Node storage node = StorageLib.nodes()[nodeAddr];
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

    function setNodesStatus(address[] calldata nodeAddrs, DataTypes.NodeStatus[] calldata status) external {
        if (nodeAddrs.length != status.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];
            DataTypes.NodeStatus s = status[i];

            // can only set node status as: Online, Offline and Initializing
            if (s == DataTypes.NodeStatus.Initializing || s == DataTypes.NodeStatus.Online) {
                StorageLib.setNodeStatus(nodeAddr, s);

                StorageLib.getNodeTime(nodeAddr).registerTime = 0;
                StorageLib.getNodeTime(nodeAddr).offlineTime = 0;
            } else if (s == DataTypes.NodeStatus.Offline) {
                StorageLib.setNodeStatus(nodeAddr, s);

                StorageLib.getNodeTime(nodeAddr).offlineTime = block.timestamp;
            } else {
                revert WrongNodeStatus();
            }
        }

        emit Events.NodeStatusSet(nodeAddrs, status);
    }

    function _validateTaxRateBasisPoints(uint64 taxRateBasisPoints) internal pure {
        if (taxRateBasisPoints > Const.DENOMINATOR) revert TaxRateBasisPointsTooLarge();
        if (taxRateBasisPoints < Const.MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();
    }

    function _validateNodeAddress(address nodeAddr) internal pure {
        if (nodeAddr == address(0)) revert NodeNotExists();
    }
}
