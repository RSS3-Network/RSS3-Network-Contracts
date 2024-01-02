// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {IChips} from "./interfaces/IChips.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {Events} from "./libraries/Events.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

//import {console2 as console} from "forge-std/console2.sol";

contract Staking is IStaking, IErrors, Pausable, Initializable, AccessControlEnumerable {
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    uint256 public constant SHARES_PER_CHIP = 500 * 10 ** 18;

    /// @dev slash fraction
    uint256 internal _nodeSlashFraction;
    uint256 internal _userSlashFraction;

    /// @dev the ratio of staked tokens to total tokens, 1/25 by default.
    /// node operator can receive its full tax if it stakes at least 1/25 of the tokens staked by external delegators
    uint256 internal _stakeRatio;

    /// @dev the baseline of staked tokens, 10,000 by default.
    /// node operator can receive its full tax if it stakes at least 10,000 tokens
    uint256 internal _stakeBaseline;

    /// @dev the baseline of deposited tokens, [TODO] by default.
    uint256 internal _depositBaseline;

    /// @dev the treasury receives all unqualified rewards, e.g. the exceeding part of the tax
    address internal _treasury;

    /// @dev the period of time that node operator can't withdraw staked tokens
    uint256 internal _depositUnbondingPeriod;
    /// @dev the period of time that user can't withdraw staked tokens
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

    /// @dev public pool
    DataTypes.Node internal _publicPool;

    /// @dev the chips contract
    address internal _chips;
    /// @dev the staking token contract
    address internal _token;

    /// @dev the issuers of chips
    mapping(uint256 tokenId => address nodeAddr) internal _issuers;

    /// @dev current epoch
    uint256 internal _currentEpoch;

    /// ACL
    // keccak256("PAUSE_ROLE");
    bytes32 public constant PAUSE_ROLE = 0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;
    // keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    /// @inheritdoc IStaking
    function initialize(
        address pauseAccount,
        address oracleAccount,
        address chips,
        address token,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        uint256 nodeSlashFraction,
        uint256 userSlashFraction,
        uint256 stakeRatio,
        uint256 stakeBaseline,
        uint256 depositBaseline,
        address treasury
    ) external override initializer {
        _chips = chips;
        _token = token;

        _stakeUnbondingPeriod = stakeUnbondingPeriod;
        _depositUnbondingPeriod = depositUnbondingPeriod;

        _nodeSlashFraction = nodeSlashFraction;
        _userSlashFraction = userSlashFraction;

        _stakeRatio = stakeRatio;
        _stakeBaseline = stakeBaseline;

        _depositBaseline = depositBaseline;

        _treasury = treasury;

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
        // TODO: get nodeAddr from msg.sender
        DataTypes.Node storage node = _nodes[nodeAddr];
        // can't delete a node not operated by msg.sender
        if (msg.sender != node.account) revert CallerNotNodeOwner();

        // can't delete a node with staked or deposited tokens
        if (node.operatorPool > 0 || node.rewardPool > 0) revert NodeStakedOrDeposited();

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
        if (publicGood) revert PublicGoodNotAllowed();

        _createNode(msg.sender, name, description, taxFraction, publicGood, endpoint);
        _deposit(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function deposit(uint256 amount) external override whenNotPaused {
        _deposit(msg.sender, amount);
    }

    /// @inheritdoc IStaking
    function requestWithdrawal(uint256 amount) external override whenNotPaused returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert NodeNotExists();

        //  deposited tokens has been slashed completely
        if (amount > node.operatorPool) revert DepositedTokensSlashedAll();

        node.operatorPool -= amount;

        requestId = ++_pendingWithdrawalCounter;

        DataTypes.WithdrawalRequest storage req = _pendingWithdrawals[requestId];
        req.timestamp = uint40(block.timestamp);
        req.owner = msg.sender;
        req.amount = amount;

        emit Events.WithdrawRequested(msg.sender, amount, requestId);
    }

    /// @inheritdoc IStaking
    function setTaxFraction4Node(address nodeAddr, uint64 taxFraction) external override {
        if (taxFraction > _denominator()) revert TaxFractionTooLarge();

        DataTypes.Node storage node = _nodes[nodeAddr];
        if (msg.sender != node.account) revert CallerNotNodeOwner();

        node.taxFraction = taxFraction;

        emit Events.NodeTaxFractionSet(nodeAddr, taxFraction);
    }

    /// @inheritdoc IStaking
    function setTaxFraction4PublicPool(uint64 taxFraction) external override onlyRole(ORACLE_ROLE) {
        if (taxFraction > _denominator()) revert TaxFractionTooLarge();

        _publicPool.taxFraction = taxFraction;

        emit Events.PublicPoolTaxFractionSet(taxFraction);
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
        if (node.account == address(0)) revert NodeNotExists();

        (startTokenId, endTokenId) = _stakeToNode(node, amount);

        // update chips issuers
        // TODO: gas optimization
        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            _issuers[i] = nodeAddr;
        }
    }

    /// @inheritdoc IStaking
    function requestUnstake(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external override whenNotPaused returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert NodeNotExists();

        // check and burn chips
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert NotChipsOwner(tokenId);

            if (_issuers[tokenId] != nodeAddr) revert NotTokenIssuer(tokenId, nodeAddr);

            IChips(_chips).burn(tokenId);
        }

        requestId = ++_pendingUnstakeCounter;

        // update rewards
        uint256 shares = SHARES_PER_CHIP * chipsIds.length;
        uint256 unstakeAmount = (shares * node.rewardPool) / node.totalShares;

        // add to request queue
        DataTypes.UnstakeRequest storage req = _pendingUnstake[requestId];
        req.timestamp = block.timestamp;
        req.owner = msg.sender;
        req.nodeAddr = nodeAddr;
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
        uint256 startTime,
        uint256 endTime,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestBonuses,
        uint256[] calldata stakingRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeAddrs.length != requestFees.length ||
            nodeAddrs.length != requestBonuses.length ||
            nodeAddrs.length != stakingRewards.length
        ) revert InvalidArrayLength();

        if (epoch != ++_currentEpoch) revert InvalidEpoch(_currentEpoch, epoch);

        uint256[] memory taxAmounts = new uint256[](nodeAddrs.length);
        // update node rewards
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) {
                // if node not exists, send rewards to public pool
                node = _publicPool;
            }

            // request bonus and staking rewards are sent to reward pool
            uint256 rewardPool = requestBonuses[i] + stakingRewards[i];
            uint256 tax = _getTax(rewardPool, node.taxFraction, node.operatorPool, node.rewardPool);
            // request fee and tax are sent to operator pool
            uint256 operatorPool = requestFees[i] + tax;
            taxAmounts[i] = tax;
            rewardPool -= tax;

            // update node
            node.operatorPool += operatorPool;
            // all after-tax rewards and request bonus are sent to the reward pool
            node.rewardPool += rewardPool;
        }

        emit Events.RewardDistributed(
            epoch,
            startTime,
            endTime,
            nodeAddrs,
            requestFees,
            requestBonuses,
            stakingRewards,
            taxAmounts
        );
    }

    /// @inheritdoc IStaking
    function stakeToPublicPool(
        uint256 amount
    ) external override whenNotPaused returns (uint256 startTokenId, uint256 endTokenId) {
        return _stakeToNode(_publicPool, amount);
    }

    /// @inheritdoc IStaking
    function requestUnstakeFromPublicPool(uint256[] calldata chipsIds) external override returns (uint256 requestId) {
        // check and burn chips
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert NotChipsOwner(tokenId);

            if (_issuers[tokenId] != address(0)) revert ChipsDelegatedOrNotPublicGood(tokenId);

            IChips(_chips).burn(tokenId);
        }

        requestId = ++_pendingUnstakeCounter;

        // update rewards
        uint256 shares = SHARES_PER_CHIP * chipsIds.length;
        uint256 unstakeAmount = (shares * _publicPool.rewardPool) / _publicPool.totalShares;

        // add to request queue
        DataTypes.UnstakeRequest storage req = _pendingUnstake[requestId];
        req.timestamp = block.timestamp;
        req.owner = msg.sender;
        req.nodeAddr = _publicPool.account;
        req.unstakeAmount = unstakeAmount;

        emit Events.UnstakeRequested(msg.sender, _publicPool.account, requestId, chipsIds);
    }

    /// @inheritdoc IStaking
    function delegate(address nodeAddr, uint256[] calldata chipsIds) external override {
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert NotChipsOwner(tokenId);

            if (_issuers[tokenId] != address(0)) revert ChipsDelegatedOrNotPublicGood(tokenId);

            _issuers[tokenId] = nodeAddr;
        }

        emit Events.Delegated(msg.sender, nodeAddr, chipsIds);
    }

    /// @inheritdoc IStaking
    function undelegate(address nodeAddr, uint256[] calldata chipsIds) external override {
        for (uint256 i = 0; i < chipsIds.length; i++) {
            uint256 tokenId = chipsIds[i];
            if (IERC721(_chips).ownerOf(tokenId) != msg.sender) revert NotChipsOwner(tokenId);

            if (_issuers[tokenId] != nodeAddr) revert NotTokenIssuer(tokenId, nodeAddr);

            delete _issuers[tokenId];
        }

        emit Events.Undelegated(msg.sender, nodeAddr, chipsIds);
    }

    /// @inheritdoc IStaking
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) revert NodeNotExists();

            // slash operator pool tokens
            uint256 slashedOperatorPool = (node.operatorPool * _nodeSlashFraction) / _denominator();
            node.operatorPool -= slashedOperatorPool;

            // slash reward pool tokens
            uint256 slashedRewardPool = (node.rewardPool * _userSlashFraction) / _denominator();
            node.rewardPool -= slashedRewardPool;

            node.slashedAmount += slashedOperatorPool + slashedRewardPool;

            emit Events.NodeSlashed(nodeAddrs[i], slashedOperatorPool, slashedRewardPool);
        }
    }

    /// @inheritdoc IStaking
    function getPendingWithdrawal(
        uint256 requestId
    ) external view override returns (DataTypes.WithdrawalRequest memory) {
        return _pendingWithdrawals[requestId];
    }

    /// @inheritdoc IStaking
    function getPendingUnstake(uint256 requestId) external view override returns (DataTypes.UnstakeRequest memory) {
        return _pendingUnstake[requestId];
    }

    /// @inheritdoc IStaking
    function minTokensToStake(address nodeAddr) external view override returns (uint256) {
        return _minTokensToStake(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getChipsInfo(uint256 tokenId) external view override returns (address nodeAddr, uint256 tokens) {
        nodeAddr = _issuers[tokenId];
        tokens = _minTokensToStake(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getPublicPool() external view override returns (DataTypes.Node memory) {
        return _publicPool;
    }

    /// @inheritdoc IStaking
    function getNodeCount() external view override returns (uint256) {
        return _nodeAddrs.length();
    }

    /// @inheritdoc IStaking
    function getNodes(uint256 offset, uint256 limit) external view override returns (DataTypes.Node[] memory nodes) {
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
    function currentEpoch() external view override returns (uint256) {
        return _currentEpoch;
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
        if (address(0) != node.account) revert NodeExists();
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
        if (node.account == address(0)) revert NodeNotExists();

        // update operator pool
        node.operatorPool += amount;

        // transfer tokens
        IERC20(_token).safeTransferFrom(nodeAddr, address(this), amount);

        emit Events.Deposited(nodeAddr, amount);
    }

    /// @dev stakes tokens to a node
    function _stakeToNode(
        DataTypes.Node storage node,
        uint256 amount
    ) internal returns (uint256 startTokenId, uint256 endTokenId) {
        uint256 shares = _tokensToShares(amount, node.rewardPool, node.totalShares);
        uint256 chipsCount = shares / SHARES_PER_CHIP;
        if (chipsCount == 0) revert AmountTooSmall(amount);
        // mint chips
        (startTokenId, endTokenId) = IChips(_chips).mintBatch(msg.sender, chipsCount);

        // update stakedAmount
        uint256 stakedAmount = _sharesToTokens(chipsCount * SHARES_PER_CHIP, node.totalShares, node.rewardPool);
        node.rewardPool += stakedAmount;
        // update total shares
        node.totalShares += (chipsCount * SHARES_PER_CHIP);
        // transfer tokens
        IERC20(_token).safeTransferFrom(msg.sender, address(this), stakedAmount);

        emit Events.Staked(msg.sender, node.account, stakedAmount, startTokenId, endTokenId);
    }

    /// @dev claim unstake request
    function _claimUnstake(uint256 requestId) internal {
        DataTypes.UnstakeRequest memory req = _pendingUnstake[requestId];
        if (block.timestamp < req.timestamp + _stakeUnbondingPeriod) revert ClaimTimeNotReady();

        // transfer
        IERC20(_token).safeTransfer(req.owner, req.unstakeAmount);

        // delete request
        delete _pendingUnstake[requestId];

        emit Events.UnstakeClaimed(requestId, req.nodeAddr, req.owner, req.unstakeAmount);
    }

    /// @dev claim withdrawal request
    function _claimWithdrawal(uint256 requestId) internal {
        DataTypes.WithdrawalRequest memory req = _pendingWithdrawals[requestId];

        // TODO: should we revert or just skip this claim?
        if (req.owner == address(0)) revert ClaimIdNotExists();

        if (block.timestamp < req.timestamp + _depositUnbondingPeriod) revert ClaimTimeNotReady();

        // transfer staked tokens
        IERC20(_token).safeTransfer(req.owner, req.amount);

        // delete request
        delete _pendingWithdrawals[requestId];

        emit Events.WithdrawalClaimed(requestId);
    }

    /// @dev get minimal tokens to stake for a node
    function _minTokensToStake(address nodeAddr) internal view returns (uint256) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.totalShares == 0) {
            return SHARES_PER_CHIP;
        }

        return (SHARES_PER_CHIP * node.rewardPool) / node.totalShares;
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
        uint256 operatorPool,
        uint256 rewardPool
    ) internal view returns (uint256) {
        if (operatorPool == 0) return 0;

        uint256 stakeCapacity = operatorPool * _stakeRatio;
        if (rewardPool <= stakeCapacity) {
            // node will receive its full tax
            return (rewards * taxFraction) / _denominator();
        }

        uint256 stakingRewards = (rewards * stakeCapacity) / operatorPool;
        return (stakingRewards * taxFraction) / _denominator();
    }

    /// @dev convert shares to equivalent tokens
    function _sharesToTokens(uint256 shares, uint256 totalShares, uint256 totalAmount) internal pure returns (uint256) {
        if (totalShares == 0) {
            return shares;
        }

        return (shares * totalAmount) / totalShares;
    }

    /// @dev convert tokens to equivalent shares
    function _tokensToShares(uint256 amount, uint256 totalAmount, uint256 totalShares) internal pure returns (uint256) {
        if (totalAmount == 0) {
            return amount;
        }

        return (amount * totalShares) / totalAmount;
    }

    /**
     * @dev doniminator
     */
    function _denominator() internal pure virtual returns (uint96) {
        return 10000;
    }
}
