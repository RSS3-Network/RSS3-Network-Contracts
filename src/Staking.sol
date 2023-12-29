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
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

//import {console2 as console} from "forge-std/console2.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant SHARES_PER_CHIP = 500 * 10 ** 18;
    uint256 public constant firstDepositAmount = 10000 * 10 ** 18;

    uint256 public constant STAKE_RATIO = 25;

    /// @dev The period of time that node operator can't withdraw staked tokens
    uint256 internal _depositUnbondingPeriod;
    /// @dev The period of time that user can't withdraw staked tokens
    uint256 internal _stakeUnbondingPeriod;

    /// @dev all node addresses
    EnumerableSet.AddressSet internal _nodeAddrs;
    /// @dev all node info
    mapping(address nodeAddr => DataTypes.Node) internal _nodes;

    /// @dev pending withdrawal request counter
    uint256 internal _pendingWithdrawalCounter;
    /// @dev pending withdrawal request
    mapping(uint256 requestId => DataTypes.WithdrawalRequest) internal _pendingWithdrawals;

    /// @dev unstake request queue counter
    uint256 internal _pendingUnstakeCounter;
    /// @dev unstake request queue
    mapping(uint256 requestId => DataTypes.UnstakeRequest) internal _pendingUnstake;

    /// @dev the chips contract
    address internal _chips;
    /// @dev the staking token contract
    address internal _token;

    /// @dev the issuers of chips
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
        uint256 depositUnbondingPeriod
    ) external override initializer {
        _chips = chips;
        _token = token;

        _stakeUnbondingPeriod = stakeUnbondingPeriod;
        _depositUnbondingPeriod = depositUnbondingPeriod;

        _grantRole(PAUSE_ROLE, pauseAccount);
        _grantRole(ORACLE_ROLE, oracleAccount);
    }

    /// @inheritdoc IStaking
    function pause() external override onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @inheritdoc IStaking
    function unpause() external override whenPaused onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    /// @inheritdoc IStaking
    function createNode(
        address to,
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint
    ) external override {
        _createNode(to, name, description, taxFraction, publicGood, endpoint);
    }

    /// @inheritdoc IStaking
    function deleteNode(address nodeAddr) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (msg.sender != node.account) revert Errors.CallerNotNodeOwner();

        // can't delete a node with staked or deposited tokens
        if (node.stakedAmount > 0 || node.depositAmount > 0) revert Errors.NodeStakedOrDeposited();

        delete _nodes[nodeAddr];
        _nodeAddrs.remove(nodeAddr);

        emit Events.NodeDeleted(nodeAddr);
    }

    /// @inheritdoc IStaking
    function createNodeAndDeposit(
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint,
        uint256 amount
    ) external override whenNotPaused {
        if (publicGood) revert Errors.PublicGoodNotAllowed();

        _createNode(msg.sender, name, description, taxFraction, publicGood, endpoint);
        _deposit(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function deposit(uint256 amount) external override whenNotPaused {
        _deposit(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function requestWithdrawal(
        uint256 amount
    ) external override whenNotPaused returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        //  deposited tokens has been slashed completely
        if (amount > node.depositAmount) revert Errors.DepositedTokensSlashedAll();

        node.depositAmount -= amount;

        requestId = ++_pendingWithdrawalCounter;

        DataTypes.WithdrawalRequest storage req = _pendingWithdrawals[requestId];
        req.timestamp = uint40(block.timestamp);
        req.owner = msg.sender;
        req.amount = amount;

        // withdraw operator pool rewards
        // TODO: 30 epoches later
        _withdrawOperatorPoolRewards(node);

        emit Events.WithdrawRequested(msg.sender, amount, requestId);
    }

    /// @inheritdoc IStaking
    function setNodeTaxFraction(address nodeAddr, uint64 taxFraction) external override {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (msg.sender != node.account) revert Errors.CallerNotNodeOwner();

        node.taxFraction = taxFraction;

        emit Events.NodeTaxFractionSet(nodeAddr, taxFraction);
    }

    /// @inheritdoc IStaking
    function withdrawOperatorPoolRewards(address nodeAddr) external override whenNotPaused {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        _withdrawOperatorPoolRewards(node);
    }

    /// @inheritdoc IStaking
    function withdrawTax(address nodeAddr) external override whenNotPaused {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        uint256 claimableTax = node.tax - node.claimedTax;

        IERC20(_token).safeTransfer(node.account, claimableTax);

        emit Events.TaxWithdrawn(node.account, claimableTax);
    }

    /// @inheritdoc IStaking
    function claimWithdrawal(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimWithdrawal(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function stake(
        address nodeAddr,
        uint256 amount
    ) external override whenNotPaused returns (uint256 startTokenId, uint256 endTokenId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // validate node
        if (node.account == address(0)) revert Errors.NodeNotExists();

        uint256 shares = _getShares(node, amount);
        uint256 chipsCount = shares / SHARES_PER_CHIP;
        if (chipsCount == 0) revert Errors.AmountTooSmall();
        // mint chips
        (startTokenId, endTokenId) = IChips(_chips).mintBatch(msg.sender, chipsCount);

        // update issuers
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            _issuers[i] = nodeAddr;
        }

        // update stakedAmount
        uint256 stakedAmount = _sharesToTokens(node, chipsCount * SHARES_PER_CHIP);
        node.stakedAmount += stakedAmount;
        // update total shares
        node.totalShares += (chipsCount * SHARES_PER_CHIP);
        // transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), stakedAmount);

        emit Events.Staked(msg.sender, nodeAddr, stakedAmount, startTokenId, endTokenId);
    }

    /// @inheritdoc IStaking
    function requestUnstake(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external override whenNotPaused returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        // check and burn chips
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert Errors.NotChipsOwner();

            if (_issuers[tokenId] != nodeAddr) revert Errors.NotTokenIssuer(tokenId, nodeAddr);

            IChips(_chips).burn(tokenId);
        }

        requestId = ++_pendingUnstakeCounter;

        // update rewards
        uint256 shares = SHARES_PER_CHIP * chipsIds.length;
        uint256 rewards = (shares * node.rewardPoolRewards) / node.totalShares;
        uint256 unstakeAmount = (shares * node.stakedAmount) / node.totalShares;

        // add to request queue
        DataTypes.UnstakeRequest storage req = _pendingUnstake[requestId];
        req.timestamp = block.timestamp;
        req.owner = msg.sender;
        req.nodeAddr = nodeAddr;
        req.rewards = rewards;
        req.unstakeAmount = unstakeAmount;

        emit Events.UnstakeRequested(msg.sender, nodeAddr, requestId, chipsIds);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimUnstake(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function distributeRewards(
        uint256 epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestBonuses,
        uint256[] calldata stakingRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeAddrs.length != requestFees.length ||
            nodeAddrs.length != requestBonuses.length ||
            nodeAddrs.length != stakingRewards.length
        ) revert Errors.InvalidArrayLength();

        uint256[] memory taxAmounts = new uint256[](nodeAddrs.length);
        // update node rewards
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            // request fee is send to operator pool
            node.operatorPoolRewards += requestFees[i];

            // request bonus and staking rewards are sent to reward pool
            uint256 rewardPoolRewards = requestBonuses[i] + stakingRewards[i];

            // tax is sent to node operator
            uint256 tax = _getTax(
                rewardPoolRewards,
                node.taxFraction,
                node.depositAmount,
                node.stakedAmount
            );
            node.tax += tax;
            taxAmounts[i] = tax;

            uint256 rewardsAfterTax = rewardPoolRewards - tax;
            // all after-tax rewards and request bonus are sent to the reward pool
            node.rewardPoolRewards += rewardsAfterTax;
        }

        emit Events.RewardDistributed(
            epoch,
            startTimestamp,
            endTimestamp,
            nodeAddrs,
            requestFees,
            requestBonuses,
            stakingRewards,
            taxAmounts
        );
    }

    /// @inheritdoc IStaking
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) revert Errors.NodeNotExists();

            // TODO: slash node
            uint256 slashedAmount;

            emit Events.NodeSlashed(nodeAddrs[i], slashedAmount);
        }
    }

    /// @inheritdoc IStaking
    function getPendingWithdrawal(
        uint256 requestId
    ) external view override returns (DataTypes.WithdrawalRequest memory) {
        return _pendingWithdrawals[requestId];
    }

    /// @inheritdoc IStaking
    function getPendingUnstake(
        uint256 requestId
    ) external view override returns (DataTypes.UnstakeRequest memory) {
        return _pendingUnstake[requestId];
    }

    /// @inheritdoc IStaking
    function minTokensToStake(address nodeAddr) external view override returns (uint256) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.totalShares == 0) {
            return SHARES_PER_CHIP;
        }

        return (SHARES_PER_CHIP * _getPoolTokens(node)) / node.totalShares;
    }

    /// @inheritdoc IStaking
    function getChipsInfo(
        uint256 tokenId
    ) external view override returns (address nodeAddr, uint256 tokens) {
        nodeAddr = _issuers[tokenId];

        if (nodeAddr != address(0)) {
            DataTypes.Node storage node = _nodes[nodeAddr];
            tokens = (_getPoolTokens(node) / node.totalShares) * SHARES_PER_CHIP;
        }
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getNodeCount() external view override returns (uint256) {
        return _nodeAddrs.length();
    }

    /// @inheritdoc IStaking
    function getNodes(
        uint256 offset,
        uint256 limit
    ) external view override returns (DataTypes.Node[] memory nodes) {
        uint256 totalNodes = _nodeAddrs.length();
        uint256 len = (totalNodes - offset).min(limit);
        nodes = new DataTypes.Node[](len);

        if (offset >= totalNodes) return nodes;

        for (uint256 i = offset; i < len + offset; i++) {
            address nodeAddr = _nodeAddrs.at(i);
            nodes[i - offset] = _nodes[nodeAddr];
        }
    }

    /// @inheritdoc IStaking
    function stakingToken() external view override returns (address) {
        return _token;
    }

    /// @inheritdoc IStaking
    function chipsContract() external view override returns (address) {
        return _chips;
    }

    /// @dev create a node
    function _createNode(
        address nodeAddr,
        string calldata name,
        string calldata description,
        uint64 taxFraction,
        bool publicGood,
        string calldata endpoint
    ) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a non-exist node
        if (address(0) != node.account) revert Errors.NodeExists();
        node.account = nodeAddr;
        node.name = name;
        node.description = description;
        node.taxFraction = taxFraction;
        node.publicGood = publicGood;
        node.endpoint = endpoint;

        // add to node list
        _nodeAddrs.add(nodeAddr);

        emit Events.NodeCreated(nodeAddr, name, description, taxFraction, publicGood, endpoint);
    }

    function _deposit(address nodeAddr, uint256 amount) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert Errors.NodeNotExists();

        if (node.depositAmount == 0 && amount < firstDepositAmount) revert Errors.AmountTooSmall();

        // update operator pool
        node.depositAmount += amount;

        // transfer tokens
        IERC20(_token).safeTransferFrom(nodeAddr, address(this), amount);

        emit Events.Deposited(nodeAddr, amount);
    }

    /// @dev claim unstake request
    function _claimUnstake(uint256 requestId) internal {
        DataTypes.UnstakeRequest storage req = _pendingUnstake[requestId];

        if (req.isClaimed) revert Errors.AlreadyClaimed();
        if (block.timestamp - req.timestamp < _stakeUnbondingPeriod)
            revert Errors.ClaimTimeNotReady();

        // set claimed status
        req.isClaimed = true;

        // transfer
        IERC20(_token).safeTransfer(req.owner, req.unstakeAmount);
        IERC20(_token).safeTransfer(req.owner, req.rewards);

        emit Events.UnstakeClaimed(
            requestId,
            req.nodeAddr,
            req.owner,
            req.unstakeAmount,
            req.rewards
        );
    }

    /// @dev claim withdrawal request
    function _claimWithdrawal(uint256 requestId) internal {
        DataTypes.WithdrawalRequest storage req = _pendingWithdrawals[requestId];

        if (req.isClaimed) revert Errors.AlreadyClaimed();
        if (block.timestamp - req.timestamp < _depositUnbondingPeriod)
            revert Errors.ClaimTimeNotReady();

        // set claimed status
        req.isClaimed = true;

        // transfer staked tokens
        IERC20(_token).safeTransfer(req.owner, req.amount);

        emit Events.WithdrawalClaimed(requestId);
    }

    /// @dev withdraw operator pool rewards
    function _withdrawOperatorPoolRewards(DataTypes.Node storage node) internal {
        // get rewards
        uint256 rewards = _getOperatorPoolRewards(node);

        // update claimed rewards
        node.claimedOperatorPoollRewards = node.operatorPoolRewards;

        // transfer rewards
        IERC20(_token).safeTransfer(node.account, rewards);

        emit Events.OperatorPoolRewardsWithdrawn(node.account, node.account, rewards);
    }

    function _sharesToTokens(
        DataTypes.Node storage node,
        uint256 shares
    ) internal view returns (uint256) {
        if (node.totalShares == 0) {
            return shares;
        }

        return (shares * _getPoolTokens(node)) / node.totalShares;
    }

    /// @dev get pool tokens from a node operator, it includes: user delegated tokens and rewards
    function _getPoolTokens(DataTypes.Node memory node) internal pure returns (uint256) {
        return node.rewardPoolRewards + node.stakedAmount;
    }

    /// @dev get operator pool rewards
    function _getOperatorPoolRewards(DataTypes.Node memory node) internal pure returns (uint256) {
        return node.operatorPoolRewards - node.claimedOperatorPoollRewards;
    }

    /// @dev get shares amount
    function _getShares(
        DataTypes.Node memory node,
        uint256 stakeAmount
    ) internal pure returns (uint256 sharesAmount) {
        if (node.totalShares == 0) {
            sharesAmount = stakeAmount;
        } else {
            sharesAmount = (stakeAmount * _getPoolTokens(node)) / node.totalShares;
        }
    }

    /**
     * @dev get tax amount
     *  For a node operator to receive its full tax,
     * it needs to stake at least 1/25 of the tokens staked by external delegators,
     * or the exceeding part of the tax will be sent to the reward pool.
     */
    function _getTax(
        uint256 rewards,
        uint256 taxFraction,
        uint256 depositAmount,
        uint256 stakedAmount
    ) internal pure returns (uint256) {
        uint256 stakeCapacity = depositAmount * STAKE_RATIO;
        if (stakedAmount <= stakeCapacity) {
            // node will receive its full tax
            return (rewards * taxFraction) / _taxDenominator();
        }

        uint256 stakingRewards = (rewards * stakeCapacity) / stakedAmount;
        return (stakingRewards * taxFraction) / _taxDenominator();
    }

    /**
     * @dev The denominator with which to interpret the tax as a fraction.
     * Defaults to 10000 so tax is expressed in basis points.
     */
    function _taxDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
