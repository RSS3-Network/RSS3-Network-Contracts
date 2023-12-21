// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IStaking} from "./interfaces/IStaking.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {
    ErrCallerNotStaking,
    ErrNodeExists,
    ErrCallerNotNodeOwner,
    ErrNodeNotExists
} from "./libraries/Error.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;

    uint256 public constant minStakeAmount = 10000e18;

    EnumerableSet.UintSet internal _nodeIds;
    mapping(uint256 nodeId => address nodeAddr) internal _nodeIdToAddr;
    mapping(address nodeAddr => uint256 nodeId) internal _nodeAddrToId;
    mapping(uint256 nodeId => DataTypes.Node) internal _nodes;

    // The chips contract
    address internal _chips;
    // The staking token contract
    address internal _token;
    uint256 internal _nodeIdCounter;

    /// ACL
    bytes32 public constant PAUSE_ROLE =
        0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d; // keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE =
        0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1; // keccak256("ORACLE_ROLE");

    /// @inheritdoc IStaking
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token
    ) external override initializer {
        _chips = chips;
        _token = token;

        _setupRole(PAUSE_ROLE, pauseAccount);
        _setupRole(ORACLE_ROLE, oracleAccount);
    }

    /// @inheritdoc IStaking
    function pause() external override whenNotPaused onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @inheritdoc IStaking
    function unpause() external override whenPaused onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    /// @inheritdoc IStaking
    function createNode(
        string calldata name,
        string calldata description,
        address rewardAddress
    ) external override returns (uint256 nodeId) {
        nodeId = _nodeAddrToId[msg.sender];
        if (nodeId != 0) revert ErrNodeExists();

        nodeId = ++_nodeIdCounter;

        _nodeAddrToId[msg.sender] = nodeId;
        _nodeIdToAddr[nodeId] = msg.sender;

        DataTypes.Node storage node = _nodes[nodeId];
        node.id = nodeId;
        node.account = msg.sender;
        node.name = name;
        node.description = description;
        node.rewardAddress = rewardAddress;
    }

    /// @inheritdoc IStaking
    function deleteNode(address addr) external override {
        if (msg.sender != addr) revert ErrCallerNotNodeOwner();

        uint256 nodeId = _nodeAddrToId[addr];
        if (nodeId == 0) revert ErrNodeNotExists();

        delete _nodeAddrToId[addr];
        delete _nodeIdToAddr[nodeId];
        delete _nodes[nodeId];
        _nodeIds.remove(nodeId);
    }

    /// @inheritdoc IStaking
    function setNodeOperatorRewardAddress(
        address nodeAddr,
        address rewardAddress
    ) external override {}

    /// @inheritdoc IStaking
    function stake(uint256 amount) external override {
        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IStaking
    function requestUnstake(uint256 amount) external override {}

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {
        uint256 amount;
        IERC20(_token).safeTransfer(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function delegate(
        address nodeAddr,
        uint256 amount
    ) external override returns (uint256, uint256) {
        return (0, 0);
    }

    /// @inheritdoc IStaking
    function requestUndelegate(
        uint256 chipsId,
        uint256 amount
    ) external override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IStaking
    function claimUndelegate(uint256[] calldata requestIds) external override whenNotPaused {}

    /// @inheritdoc IStaking
    function distributeRewards() external override onlyRole(ORACLE_ROLE) {}

    /// @inheritdoc IStaking
    function getNodeById(uint256 nodeId) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeId];
    }

    /// @inheritdoc IStaking
    function getNodeByAddr(address addr) external view override returns (DataTypes.Node memory) {
        uint256 nodeId = _nodeAddrToId[addr];
        return _nodes[nodeId];
    }

    /// @inheritdoc IStaking
    function getNodes() external view override returns (DataTypes.Node[] memory) {
        uint256 len = _nodeIds.length();
        DataTypes.Node[] memory res = new DataTypes.Node[](len);
        for (uint256 i = 0; i < len; i++) {
            uint256 nodeId = _nodeIds.at(i);
            res[i] = _nodes[i];
        }
        return res;
    }
}
