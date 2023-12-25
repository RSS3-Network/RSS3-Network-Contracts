// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {IChips} from "./interfaces/IChips.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Errors} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant sharesPerChips = 5000e18;
    uint256 public constant firstStakingAmount = 10000e18;
    uint256 public constant minDelegateAmount = 1000e18;

    uint256 internal _stakeUnbondingPeriod;
    uint256 internal _delegateUnbondingPeriod;

    EnumerableSet.AddressSet internal _nodeAddrs;
    mapping(address nodeAddr => DataTypes.Node) internal _nodes;

    uint256 internal _unstakeRequestCounter;
    mapping(uint256 requestId => DataTypes.UnstakeRequest) internal _unstakeQueue;

    uint256 internal _undelegateRequestCounter;
    mapping(uint256 requestId => DataTypes.UndelegateRequest) internal _undelegateQueue;

    // The chips contract
    address internal _chips;
    // The staking token contract
    address internal _token;

    mapping(uint256 tokenId => address nodeAddr) internal _issuers;

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
        address token,
        uint256 stakeUnbondingPeriod,
        uint256 delegateUnbondingPeriod
    ) external override initializer {
        _chips = chips;
        _token = token;

        _stakeUnbondingPeriod = stakeUnbondingPeriod;
        _delegateUnbondingPeriod = delegateUnbondingPeriod;

        _grantRole(PAUSE_ROLE, pauseAccount);
        _grantRole(ORACLE_ROLE, oracleAccount);
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
    ) external override {
        DataTypes.Node storage node = _nodes[msg.sender];
        // can't delete a non-exist node
        if (address(0) != node.account) revert Errors.NodeExists();

        node.account = msg.sender;
        node.name = name;
        node.description = description;
        node.publicGood = publicGood;
        node.taxFraction = taxFraction;
        node.rewardAddress = rewardAddress;

        emit Events.NodeCreated(
            msg.sender,
            name,
            description,
            publicGood,
            taxFraction,
            rewardAddress
        );
    }

    /// @inheritdoc IStaking
    function deleteNode(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (msg.sender != node.account) revert Errors.CallerNotNodeOwner();

        // can't delete a node with staked or delegated tokens
        if (node.delegatedAmount > 0 || node.selfStakedAmount > 0)
            revert Errors.NodeStakedOrDelegated();

        delete _nodes[nodeAddr];
        _nodeAddrs.remove(nodeAddr);

        emit Events.NodeDeleted(nodeAddr);
    }

    /// @inheritdoc IStaking
    function setNodeRewardAddress(address nodeAddr, address rewardAddress) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (node.account != msg.sender) revert Errors.CallerNotNodeOwner();

        node.rewardAddress = rewardAddress;

        emit Events.NodeRewardAddressSet(nodeAddr, rewardAddress);
    }

    /// @inheritdoc IStaking
    function setNodeTaxFraction(address nodeAddr, uint40 taxFraction) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (msg.sender != node.account) revert Errors.CallerNotNodeOwner();

        node.taxFraction = taxFraction;

        emit Events.NodeTaxFractionSet(nodeAddr, taxFraction);
    }

    /// @inheritdoc IStaking
    function stake(uint256 amount) external override {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert Errors.NodeNotExists();
        // update operator pool
        if (node.selfStakedAmount == 0 && amount < firstStakingAmount)
            revert Errors.AmountTooSmall();
        node.selfStakedAmount = node.selfStakedAmount + amount;
        // TODO: update shares by staking amount
        // transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), amount);

        emit Events.Staked(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function requestUnstake(uint256 amount) external override returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        node.selfStakedAmount = node.selfStakedAmount - amount;

        requestId = ++_unstakeRequestCounter;

        DataTypes.UnstakeRequest storage request = _unstakeQueue[requestId];
        request.timestamp = uint40(block.timestamp);
        request.owner = msg.sender;
        request.unstakedAmount = amount;

        // withdraw operator pool rewards
        _withdrawOperatorPoolRewards(node);

        emit Events.UnstakeRequested(msg.sender, amount, requestId);
    }

    /// @inheritdoc IStaking
    function withdrawOperatorPoolRewards(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        _withdrawOperatorPoolRewards(node);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimUnstake(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function delegate(
        address nodeAddr,
        uint256 amount
    ) external override returns (uint256 startTokenId, uint256 endTokenId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        uint256 shares = (amount * (node.rewardPoolTotalRewards + node.delegatedAmount)) /
            node.totalShares;
        uint256 chipsCount = shares / sharesPerChips;
        if (chipsCount == 0) revert Errors.AmountTooSmall();

        // mint chips
        (startTokenId, endTokenId) = IChips(_chips).mintBatch(msg.sender, chipsCount);
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            _issuers[i] = nodeAddr;
        }

        uint256 remainder = (shares % sharesPerChips) *
            ((node.rewardPoolTotalRewards + node.delegatedAmount) / node.totalShares);
        uint256 delegatedAmount = amount - remainder;
        // update reward pool
        node.delegatedAmount = node.delegatedAmount + delegatedAmount;

        // transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), delegatedAmount);

        emit Events.Delegated(msg.sender, nodeAddr, delegatedAmount, startTokenId, endTokenId);

        return (startTokenId, endTokenId);
    }

    /// @inheritdoc IStaking
    function requestUndelegate(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external override returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        // check and burn chips
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert Errors.NotChipsOwner();

            if (_issuers[tokenId] != nodeAddr) revert Errors.NotTokenIssuer(tokenId, nodeAddr);

            IChips(_chips).burn(tokenId);
        }

        requestId = ++_undelegateRequestCounter;

        // update rewards
        // TODO: calculate rewards
        uint256 rewards = 0;
        uint256 undelegatedAmount = 0;

        // add to request queue
        DataTypes.UndelegateRequest storage request = _undelegateQueue[requestId];
        request.timestamp = uint40(block.timestamp);
        request.owner = msg.sender;
        request.rewards = rewards;
        request.undelegatedAmount = undelegatedAmount;
    }

    /// @inheritdoc IStaking
    function claimUndelegate(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            DataTypes.UndelegateRequest storage request = _undelegateQueue[requestIds[i]];

            if (request.claimed) revert Errors.AlreadyClaimed();
            if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
                revert Errors.ClaimTimeNotReady();

            // set claimed status
            request.claimed = true;

            // transfer
            IERC20(_token).safeTransfer(request.owner, request.undelegatedAmount);
            IERC20(_token).safeTransfer(request.owner, request.rewards);
        }
    }

    /// @inheritdoc IStaking
    function distributeRewards(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata operatorPoolRewards,
        uint256[] calldata rewardPoolRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeAddrs.length != operatorPoolRewards.length ||
            nodeAddrs.length != rewardPoolRewards.length
        ) revert Errors.InvalidArrayLength();

        // update node rewards
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];
            DataTypes.Node storage node = _nodes[nodeAddr];
            node.operatorPoolTotalRewards = node.operatorPoolTotalRewards + operatorPoolRewards[i];
            node.rewardPoolTotalRewards = node.rewardPoolTotalRewards + rewardPoolRewards[i];
        }

        emit Events.RewardDistributed(epoch, nodeAddrs, operatorPoolRewards, rewardPoolRewards);
    }

    /// @inheritdoc IStaking
    function getChipsInfo(
        uint256 tokenId
    ) external view override returns (address nodeAddr, uint256 tokens) {
        nodeAddr = _issuers[tokenId];

        if (nodeAddr != address(0)) {
            DataTypes.Node storage node = _nodes[nodeAddr];
            tokens =
                ((node.rewardPoolTotalRewards + node.delegatedAmount) / node.totalShares) *
                sharesPerChips;
        }
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getNodes() external view override returns (DataTypes.Node[] memory) {
        uint256 len = _nodeAddrs.length();
        DataTypes.Node[] memory res = new DataTypes.Node[](len);
        for (uint256 i = 0; i < len; i++) {
            address nodeAddr = _nodeAddrs.at(i);
            res[i] = _nodes[nodeAddr];
        }
        return res;
    }

    function _claimUndelegate(uint256 requestId) internal {
        DataTypes.UndelegateRequest storage request = _undelegateQueue[requestId];

        if (request.claimed) revert Errors.AlreadyClaimed();
        if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
            revert Errors.ClaimTimeNotReady();

        // set claimed status
        request.claimed = true;

        // transfer
        IERC20(_token).safeTransfer(request.owner, request.undelegatedAmount);
        IERC20(_token).safeTransfer(request.owner, request.rewards);

        emit Events.UndelegateClaimed(requestId);
    }

    function _claimUnstake(uint256 requestId) internal {
        DataTypes.UnstakeRequest storage request = _unstakeQueue[requestId];

        if (request.claimed) revert Errors.AlreadyClaimed();
        if (block.timestamp - request.timestamp < _stakeUnbondingPeriod)
            revert Errors.ClaimTimeNotReady();

        // set claimed status
        request.claimed = true;

        // transfer staked tokens
        IERC20(_token).safeTransfer(request.owner, request.unstakedAmount);

        emit Events.UnstakeClaimed(requestId);
    }

    function _withdrawOperatorPoolRewards(DataTypes.Node storage node) internal {
        // get rewards
        uint256 rewards = _getOperatorPoolRewards(node);

        // update claimed rewards
        node.claimedOperatorPoollRewards = node.operatorPoolTotalRewards;

        // transfer rewards
        IERC20(_token).safeTransfer(node.rewardAddress, rewards);

        emit Events.OperatorPoolRewardsWithdrawn(node.account, node.rewardAddress, rewards);
    }

    function _getOperatorPoolRewards(DataTypes.Node storage node) internal view returns (uint256) {
        // TODO: how to calculate operator pool rewards ?
        return node.operatorPoolTotalRewards - node.claimedOperatorPoollRewards;
    }

    /**
     * @dev The denominator with which to interpret the tax as a fraction.
     * Defaults to 10000 so tax is expressed in basis points.
     */
    function _taxDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
