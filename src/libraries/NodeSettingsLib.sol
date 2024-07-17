// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,var-name-mixedcase
pragma solidity 0.8.20;
import {DataTypes} from "./DataTypes.sol";
import {Events} from "./Events.sol";
import {StorageLib} from "../storage/StorageLib.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    CreateNodeToZeroAddress,
    NodeExists,
    NodeIsPublicGood,
    NodeNotExists,
    TaxRateBasisPointsTooLarge,
    TaxRateBasisPointsTooSmall
} from "./Errors.sol";

library NodeSettingsLib {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setTaxRateBasisPoints4Node(
        uint64 taxRateBasisPoints,
        uint256 MIN_TAX_RATE_BASIS_POINTS,
        address from
    ) external {
        if (taxRateBasisPoints > _denominator()) revert TaxRateBasisPointsTooLarge();
        if (taxRateBasisPoints < MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();

        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();

        DataTypes.Node storage node = nodes[from];

        if (address(0) == node.account) revert NodeNotExists();

        if (node.publicGood) revert NodeIsPublicGood();

        node.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.NodeTaxRateBasisPointsSet(from, taxRateBasisPoints);
    }

    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external {
        if (taxRateBasisPoints > _denominator()) revert TaxRateBasisPointsTooLarge();

        DataTypes.Node storage publicPool = StorageLib.publicPool();

        publicPool.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.PublicPoolTaxRateBasisPointsSet(taxRateBasisPoints);
    }

    function updateNode(address from, string calldata name, string calldata description) external {
        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();

        DataTypes.Node storage node = nodes[from];
        if (node.account == address(0)) revert NodeNotExists();

        node.name = name;
        node.description = description;

        emit Events.NodeUpdated(from, name, description);
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
        if (taxRateBasisPoints > _denominator()) revert TaxRateBasisPointsTooLarge();

        uint256 nodeId = StorageLib.nextNodeId();

        mapping(address => DataTypes.Node) storage nodes = StorageLib.nodes();

        bool isAlphaPhase = StorageLib.getIsAlphaPhase();

        DataTypes.Node storage node = nodes[nodeAddr];
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

    /**
     * @dev _denominator
     */
    function _denominator() internal pure returns (uint64) {
        return 10000;
    }
}
