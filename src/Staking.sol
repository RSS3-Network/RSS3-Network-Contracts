// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IStaking} from "./interfaces/IStaking.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {
    ErrCallerNotStaking,
    ErrNodeExists,
    ErrCallerNotNodeOwner,
    ErrNodeNotExists,
    ErrInvalidArrayLength,
    ErrAlreadyClaimed,
    ErrClaimTimeNotReady,
    ErrNodeStakedOrDelegated,
    ErrAmountTooSmall
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
    uint256 public constant minDelegateAmount = 1000e18;

    uint256 internal _stakeUnbondingPeriod;
    uint256 internal _delegateUnbondingPeriod;

    EnumerableSet.UintSet internal _nodeIds;
    mapping(uint256 nodeId => address nodeAddr) internal _nodeIdToAddr;
    mapping(address nodeAddr => uint256 nodeId) internal _nodeAddrToId;
    mapping(uint256 nodeId => DataTypes.Node) internal _nodes;

    uint256 internal _unstakeRequestCounter;
    mapping(uint256 requestId => DataTypes.UnstakeRequest) internal _unstakeQueue;

    uint256 internal _undelegateRequestCounter;
    mapping(uint256 requestId => DataTypes.UndelegateRequest) internal _undelegateQueue;

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

    // TODO: emit events

    /// @inheritdoc IStaking
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token,
        uint256 stakeUnbondingPeriod,
        uint256 delegateUnbondingPeriod
    ) external override initializer {
        _chips = chips;
        _token = token;

        _stakeUnbondingPeriod = stakeUnbondingPeriod;
        _delegateUnbondingPeriod = delegateUnbondingPeriod;

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
        bool publicGood,
        uint40 taxFraction,
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
        node.publicGood = publicGood;
        node.taxFraction = taxFraction;
        node.rewardAddress = rewardAddress;
    }

    /// @inheritdoc IStaking
    function deleteNode(address nodeAddr) external override {
        // can't delete a node not owned
        if (msg.sender != nodeAddr) revert ErrCallerNotNodeOwner();

        uint256 nodeId = _nodeAddrToId[nodeAddr];
        // can't delete a non-exist node
        if (nodeId == 0) revert ErrNodeNotExists();

        // can't delete a node with staked or delegated tokens
        if (_nodes[nodeId].delegatedAmount > 0 || _nodes[nodeId].selfStakedAmount > 0)
            revert ErrNodeStakedOrDelegated();

        delete _nodeAddrToId[nodeAddr];
        delete _nodeIdToAddr[nodeId];
        delete _nodes[nodeId];
        _nodeIds.remove(nodeId);
    }

    /// @inheritdoc IStaking
    function setNodeRewardAddress(address nodeAddr, address rewardAddress) external override {
        // can't update a node not owned
        if (msg.sender != nodeAddr) revert ErrCallerNotNodeOwner();

        uint256 nodeId = _nodeAddrToId[nodeAddr];
        if (nodeId == 0) revert ErrNodeNotExists();

        _nodes[nodeId].rewardAddress = rewardAddress;
    }

    /// @inheritdoc IStaking
    function setNodeTax(address nodeAddr, uint40 taxFraction) external override {
        // can't update a node not owned
        if (msg.sender != nodeAddr) revert ErrCallerNotNodeOwner();

        uint256 nodeId = _nodeAddrToId[nodeAddr];
        if (nodeId == 0) revert ErrNodeNotExists();

        _nodes[nodeId].taxFraction = taxFraction;
    }

    /// @inheritdoc IStaking
    function stake(uint256 amount) external override {
        uint256 nodeId = _nodeAddrToId[msg.sender];
        if (nodeId == 0) revert ErrNodeNotExists();

        DataTypes.Node storage node = _nodes[nodeId];
        // update operator pool
        if (node.selfStakedAmount == 0 && amount < minStakeAmount) revert ErrAmountTooSmall();
        node.selfStakedAmount = node.selfStakedAmount + amount;
        // TODO: update shares by staking amount
        // transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @inheritdoc IStaking
    function requestUnstake(uint256 amount) external override returns (uint256 requestId) {
        uint256 nodeId = _nodeAddrToId[msg.sender];
        if (nodeId == 0) revert ErrNodeNotExists();

        DataTypes.Node storage node = _nodes[nodeId];
        node.selfStakedAmount = node.selfStakedAmount - amount;

        requestId = ++_unstakeRequestCounter;

        DataTypes.UnstakeRequest storage request = _unstakeQueue[requestId];
        request.timestamp = uint40(block.timestamp);
        request.owner = msg.sender;
        request.unstakedAmount = amount;

        // withdraw operator pool rewards
        _withdrawOperatorPoolRewards(nodeId);
    }

    /// @inheritdoc IStaking
    function withdrawOperatorPoolRewards(address nodeAddr) external override {
        uint256 nodeId = _nodeAddrToId[nodeAddr];
        if (nodeId == 0) revert ErrNodeNotExists();

        _withdrawOperatorPoolRewards(nodeId);
    }

    function _withdrawOperatorPoolRewards(uint256 nodeId) internal {
        // get rewards
        uint256 rewards = _getOperatorPoolRewards(nodeId);

        // update claimed rewards
        DataTypes.Node storage node = _nodes[nodeId];
        node.claimedOperatorPoollRewards = node.operatorPoolTotalRewards;

        // transfer rewards
        IERC20(_token).safeTransfer(node.rewardAddress, rewards);
    }

    function _getOperatorPoolRewards(uint256 nodeId) internal returns (uint256) {
        // TODO: how to calculate operator pool rewards ?
        return _nodes[nodeId].operatorPoolTotalRewards - _nodes[nodeId].claimedOperatorPoollRewards;
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            DataTypes.UnstakeRequest storage request = _unstakeQueue[requestIds[i]];

            if (request.claimed) revert ErrAlreadyClaimed();
            if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
                revert ErrClaimTimeNotReady();

            // set claimed status
            request.claimed = true;

            // transfer staked tokens
            IERC20(_token).safeTransfer(request.owner, request.unstakedAmount);
        }
    }

    /// @inheritdoc IStaking
    function delegate(
        address nodeAddr,
        uint256 amount
    ) external override returns (uint256 fromTokenId, uint256 toTokenId) {
        return (0, 0);
    }

    /// @inheritdoc IStaking
    function requestUndelegate(
        uint256 fromTokenId,
        uint256 toTokenId
    ) external override returns (uint256 requestId) {
        requestId = 0;
    }

    /// @inheritdoc IStaking
    function claimUndelegate(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            DataTypes.UndelegateRequest storage request = _undelegateQueue[requestIds[i]];

            if (request.claimed) revert ErrAlreadyClaimed();
            if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
                revert ErrClaimTimeNotReady();

            // set claimed status
            request.claimed = true;

            // transfer
            IERC20(_token).safeTransfer(request.owner, request.undelegatedAmount);
            IERC20(_token).safeTransfer(request.owner, request.rewards);
        }
    }

    /// @inheritdoc IStaking
    function distributeRewards(
        uint256[] calldata nodeIds,
        uint256[] calldata operatorPoolRewards,
        uint256[] calldata rewardPoolRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeIds.length != operatorPoolRewards.length ||
            nodeIds.length != rewardPoolRewards.length
        ) revert ErrInvalidArrayLength();

        // update node rewards
        for (uint256 i = 0; i < nodeIds.length; i++) {
            uint256 nodeId = nodeIds[i];
            DataTypes.Node storage node = _nodes[nodeId];
            node.operatorPoolTotalRewards = node.operatorPoolTotalRewards + operatorPoolRewards[i];
            node.rewardPoolTotalRewards = node.rewardPoolTotalRewards + rewardPoolRewards[i];
        }
    }

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
            res[i] = _nodes[nodeId];
        }
        return res;
    }

    /**
     * @dev The denominator with which to interpret the tax as a fraction. Defaults to 10000 so tax is expressed in basis points.
     */
    function _taxDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
