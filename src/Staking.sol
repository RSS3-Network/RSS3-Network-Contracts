// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {IChips} from "./interfaces/IChips.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {Events} from "./libraries/Events.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Staking is IStaking, IErrors, Pausable, Initializable, AccessControlEnumerable, ReentrancyGuard {
    using Math for uint256;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Checkpoints for Checkpoints.Trace160;

    uint256 public constant SHARES_PER_CHIP = 500 * 10 ** 18;

    /// @dev the ratio of total tokens to deposited tokens, 25 by default.
    /// node operator can receive its full tax if it deposits at least 1/25 of the tokens staked by external delegators
    uint256 public immutable STAKE_RATIO;

    /// @dev the treasury receives all unqualified rewards, e.g. the exceeding part of the tax
    address public immutable TREASURY;

    /// @dev slash rate
    uint256 public immutable NODE_SLASH_RATE_BASIS_POINTS;
    uint256 public immutable USER_SLASH_RATE_BASIS_POINTS;

    /// @dev the minimal tokens for deposit, 10,000 by default.
    /// node operator can receive tax if it stakes at least 10,000 tokens, otherwise nothing
    uint256 public immutable MIN_DEPOSIT;

    /// @dev the period of time that node operator can't withdraw staked tokens
    uint256 public immutable DEPOSIT_UNBONDING_PERIOD;
    /// @dev the period of time that user can't withdraw staked tokens
    uint256 public immutable STAKE_UNBONDING_PERIOD;

    /// @dev the minimum value of tax rate basis points
    uint256 public immutable MIN_TAX_RATE_BASIS_POINTS;

    /// @dev the chips contract
    address internal _chips;

    /// @dev the flag of settlement phase.
    /// stake/requestUnstake is not allowed in settlement phase.
    bool internal _isSettlementPhase;

    /// @dev the flag of alpha phase.
    /// requestUnstake/requestWithdrawal is not allowed in alpha phase.
    bool internal _isAlphaPhase;

    /// @dev all node addresses
    EnumerableSet.AddressSet internal _nodeAddrs;
    /// @dev all node info
    mapping(address nodeAddr => DataTypes.Node) internal _nodes;
    /// @dev counter of node id
    uint256 internal _nodeIdCounter;

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

    /// @dev total operation pool tokens
    uint256 internal _totalOperationPoolTokens;
    /// @dev total staking pool tokens
    uint256 internal _totalStakingPoolTokens;

    /// @dev the issuers of chips
    Checkpoints.Trace160 internal _families;
    mapping(uint256 chipId => address nodeAddr) internal _chipIssuers;

    /// @dev shares corresponding to each chip
    mapping(uint256 chipId => uint256 shares) internal _chipToShares;

    /// ACL
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    modifier whenNotAlphaPhase() {
        if (_isAlphaPhase) revert AlphaWithdrawNotAllowed();
        _;
    }

    modifier whenNotSettlementPhase() {
        if (_isSettlementPhase) revert SettlementPhase();
        _;
    }

    /**
     * @notice constructor.
     * @param treasury The address of treasury.
     * @param stakeRatio The stake ratio of the node operator.
     * @param stakeUnbondingPeriod Time in seconds user need to wait to unstake its stake.
     * @param depositUnbondingPeriod Time in seconds node operator need to wait to withdraw its deposit.
     * @param nodeSlashRateBasisPoints Slash rate in basis points for node operator.
     * @param userSlashRateBasisPoints Slash rate measured in basis points for user.
     * @param stakeRatio The stake ratio of the node operator.
     * @param minDeposit The deposit base line of the node operator.
     */
    constructor(
        address treasury,
        uint256 stakeRatio,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        uint256 nodeSlashRateBasisPoints,
        uint256 userSlashRateBasisPoints,
        uint256 minDeposit,
        uint256 minTaxRateBasisPoints
    ) {
        TREASURY = treasury;
        STAKE_RATIO = stakeRatio;

        STAKE_UNBONDING_PERIOD = stakeUnbondingPeriod;
        DEPOSIT_UNBONDING_PERIOD = depositUnbondingPeriod;

        NODE_SLASH_RATE_BASIS_POINTS = nodeSlashRateBasisPoints;
        USER_SLASH_RATE_BASIS_POINTS = userSlashRateBasisPoints;

        MIN_DEPOSIT = minDeposit;
        MIN_TAX_RATE_BASIS_POINTS = minTaxRateBasisPoints;
    }

    /// @inheritdoc IStaking
    function initialize(address chips, address pauseAccount, address oracleAccount) external override initializer {
        _chips = chips;

        _grantRole(PAUSE_ROLE, pauseAccount);
        _grantRole(ORACLE_ROLE, oracleAccount);

        _isAlphaPhase = true;
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
        string calldata name,
        string calldata description,
        uint64 taxRateBasisPoints,
        bool publicGood
    ) external payable override whenNotPaused {
        if (publicGood) {
            if (msg.value > 0) revert PublicGoodNodeNotDeposited();
            if (taxRateBasisPoints > 0) revert PublicGoodNodeTaxNotZero();
        } else {
            if (taxRateBasisPoints < MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();
        }

        _createNode(msg.sender, name, description, taxRateBasisPoints, publicGood);

        if (msg.value > 0) _deposit(msg.sender, msg.value);
    }

    /// @inheritdoc IStaking
    function updateNode(string calldata name, string calldata description) external override whenNotPaused {
        address addr = msg.sender;

        DataTypes.Node storage node = _nodes[addr];
        if (node.account == address(0)) revert NodeNotExists();

        node.name = name;
        node.description = description;

        emit Events.NodeUpdated(addr, name, description);
    }

    /// @inheritdoc IStaking
    function deposit() external payable override whenNotPaused {
        if (msg.value == 0) revert InsufficientValue();

        _deposit(msg.sender, msg.value);
    }

    /// @inheritdoc IStaking
    function requestWithdrawal(
        uint256 amount
    ) external override whenNotPaused whenNotAlphaPhase returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert NodeNotExists();

        //  withdrawal amount should not exceed the operation pool tokens
        if (amount > node.operationPoolTokens) revert ExcessWithdrawalAmount();

        return _requestWithdrawal(node, amount);
    }

    /// @inheritdoc IStaking
    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints) external override whenNotPaused {
        if (taxRateBasisPoints > _denominator()) revert TaxRateBasisPointsTooLarge();
        if (taxRateBasisPoints < MIN_TAX_RATE_BASIS_POINTS) revert TaxRateBasisPointsTooSmall();

        DataTypes.Node storage node = _nodes[msg.sender];
        if (address(0) == node.account) revert NodeNotExists();
        if (node.publicGood) revert NodeIsPublicGood();

        node.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.NodeTaxRateBasisPointsSet(msg.sender, taxRateBasisPoints);
    }

    /// @inheritdoc IStaking
    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external override onlyRole(ORACLE_ROLE) {
        if (taxRateBasisPoints > _denominator()) revert TaxRateBasisPointsTooLarge();

        _publicPool.taxRateBasisPoints = taxRateBasisPoints;

        emit Events.PublicPoolTaxRateBasisPointsSet(taxRateBasisPoints);
    }

    /// @inheritdoc IStaking
    function claimWithdrawal(uint256[] calldata requestIds) external override whenNotPaused nonReentrant {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimWithdrawal(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function stake(
        address nodeAddr
    )
        external
        payable
        override
        whenNotPaused
        whenNotSettlementPhase
        returns (uint256 startTokenId, uint256 endTokenId)
    {
        DataTypes.Node storage node = _nodes[nodeAddr];
        // validate node
        if (node.account == address(0)) revert NodeNotExists();
        if (node.publicGood) revert StakeToPublicGoodNode(nodeAddr);

        (startTokenId, endTokenId) = _stakeToNode(node, msg.value, nodeAddr);
    }

    /// @inheritdoc IStaking
    function requestUnstake(
        address nodeAddr,
        uint256[] calldata chipsIds
    ) external override whenNotPaused whenNotSettlementPhase whenNotAlphaPhase returns (uint256 requestId) {
        return _unstakeFromNode(nodeAddr, chipsIds);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused nonReentrant {
        for (uint256 i = 0; i < requestIds.length; i++) {
            _claimUnstake(requestIds[i]);
        }
    }

    /// @inheritdoc IStaking
    function distributeRewards(
        uint256[3] calldata epochInfo,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata stakingRewards,
        uint256[] calldata requestCounts,
        uint256 publicPoolRewards
    ) external payable override whenNotPaused onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != operationRewards.length || nodeAddrs.length != stakingRewards.length)
            revert InvalidArrayLength();

        // distribute rewards for public pool
        if (publicPoolRewards > 0) {
            uint256 tax = _distributePublicPoolRewards(publicPoolRewards);
            emit Events.PublicGoodRewardDistributed(epochInfo[0], epochInfo[1], epochInfo[2], publicPoolRewards, tax);
        }

        // distribute rewards for other nodes
        uint256[] memory taxCollected = _distributeNodesRewards(nodeAddrs, operationRewards, stakingRewards);

        emit Events.RewardDistributed(
            epochInfo[0],
            epochInfo[1],
            epochInfo[2],
            nodeAddrs,
            operationRewards,
            stakingRewards,
            taxCollected,
            requestCounts
        );
    }

    /// @inheritdoc IStaking
    function stakeToPublicPool(
        address nodeAddr
    )
        external
        payable
        override
        whenNotPaused
        whenNotSettlementPhase
        returns (uint256 startTokenId, uint256 endTokenId)
    {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert NodeNotExists();
        if (!node.publicGood) revert NodeNotPublicGood(nodeAddr);

        (startTokenId, endTokenId) = _stakeToNode(_publicPool, msg.value, nodeAddr);
    }

    /// @inheritdoc IStaking
    function mergeChips(uint256[] calldata chipIds) external override returns (uint256 newTokenId) {
        if (chipIds.length == 0) revert EmptyChipsIds();

        address nodeAddr = _issuerOf(chipIds[0]);
        address owner = _checkChipsConditions(nodeAddr, chipIds);

        uint256 totalShares;
        for (uint256 i = 0; i < chipIds.length; i++) {
            (, , uint256 shares) = _chipsInfo(chipIds[i]);
            totalShares += shares;
        }

        // burn chips and reset corresponding shares
        for (uint256 i = 0; i < chipIds.length; i++) {
            IChips(_chips).burn(chipIds[i]);

            _chipToShares[chipIds[i]] = 0;
            _chipIssuers[chipIds[i]] = address(0);
        }

        // mint new chip
        newTokenId = IChips(_chips).mint(owner);
        _chipIssuers[newTokenId] = nodeAddr;
        _chipToShares[newTokenId] = totalShares;

        emit Events.ChipsMerged(owner, nodeAddr, newTokenId, chipIds);
    }

    /// @inheritdoc IStaking
    function slashNodes(
        address[] calldata nodeAddrs
    ) external override whenNotPaused whenNotSettlementPhase onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0)) revert NodeNotExists();

            // slash operation pool tokens
            uint256 slashedOperationPool = (node.operationPoolTokens * NODE_SLASH_RATE_BASIS_POINTS) / _denominator();
            _decreaseOperationPool(node, slashedOperationPool);

            // slash staking pool tokens
            uint256 slashedStakingPool = (node.stakingPoolTokens * USER_SLASH_RATE_BASIS_POINTS) / _denominator();
            _decreaseStakingPool(node, slashedStakingPool);

            node.slashedTokens += slashedOperationPool + slashedStakingPool;

            emit Events.NodeSlashed(nodeAddrs[i], slashedOperationPool, slashedStakingPool);
        }
    }

    /// @inheritdoc IStaking
    function setSettlementPhase(bool enabled) external override whenNotPaused onlyRole(ORACLE_ROLE) {
        _isSettlementPhase = enabled;
    }

    /// @inheritdoc IStaking
    function disableAlphaPhase() external override whenNotPaused onlyRole(PAUSE_ROLE) {
        _isAlphaPhase = false;
    }

    /// @inheritdoc IStaking
    function withdraw2Treasury() external override {
        uint256 balance = address(this).balance;
        uint256 amount = balance - _totalOperationPoolTokens - _totalStakingPoolTokens;
        _transfer(TREASURY, amount);
    }

    /// @inheritdoc IStaking
    function isSettlementPhase() external view override returns (bool) {
        return _isSettlementPhase;
    }

    /// @inheritdoc IStaking
    function isAlphaPhase() external view override returns (bool) {
        return _isAlphaPhase;
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
    function getChipsInfo(uint256 tokenId) external view override returns (address nodeAddr, uint256 tokens) {
        (nodeAddr, tokens, ) = _chipsInfo(tokenId);
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
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return _nodes[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getNodeAvatar(address nodeAddr) external view override returns (string memory) {
        return IChips(_chips).nodeImageAndAttributesURI(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getNodes(address[] calldata nodeAddrs) external view override returns (DataTypes.Node[] memory nodes) {
        nodes = new DataTypes.Node[](nodeAddrs.length);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            nodes[i] = _nodes[nodeAddrs[i]];
        }
    }

    /// @inheritdoc IStaking
    function getNodesWithPagination(
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
    function getPoolInfo()
        external
        view
        override
        returns (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens)
    {
        totalOperationPoolTokens = _totalOperationPoolTokens;
        totalStakingPoolTokens = _totalStakingPoolTokens;
    }

    /// @inheritdoc IStaking
    function chipsContract() external view override returns (address) {
        return _chips;
    }

    function _requestWithdrawal(DataTypes.Node storage node, uint256 amount) internal returns (uint256 requestId) {
        _decreaseOperationPool(node, amount);

        requestId = ++_pendingWithdrawalCounter;

        DataTypes.WithdrawalRequest storage req = _pendingWithdrawals[requestId];
        req.timestamp = uint40(block.timestamp);
        req.owner = node.account;
        req.amount = amount;

        emit Events.WithdrawRequested(node.account, amount, requestId);

        return requestId;
    }

    /// @dev increase operation pool tokens of a node, and total operation pool tokens
    function _increaseOperationPool(DataTypes.Node storage node, uint256 amount) internal {
        node.operationPoolTokens += amount;
        _totalOperationPoolTokens += amount;
    }

    /// @dev decrease operation pool tokens of a node, and total operation pool tokens
    function _decreaseOperationPool(DataTypes.Node storage node, uint256 amount) internal {
        node.operationPoolTokens -= amount;
        _totalOperationPoolTokens -= amount;
    }

    /// @dev increase staking pool tokens of a node, and total staking pool tokens
    function _increaseStakingPool(DataTypes.Node storage node, uint256 amount) internal {
        node.stakingPoolTokens += amount;
        _totalStakingPoolTokens += amount;
    }

    /// @dev decrease staking pool tokens of a node, and total staking pool tokens
    function _decreaseStakingPool(DataTypes.Node storage node, uint256 amount) internal {
        node.stakingPoolTokens -= amount;
        _totalStakingPoolTokens -= amount;
    }

    /// @dev increase total shares of a node
    function _increaseTotalShares(DataTypes.Node storage node, uint256 amount) internal {
        node.totalShares += amount;
    }

    /// @dev decrease total shares of a node
    function _decreaseTotalShares(DataTypes.Node storage node, uint256 amount) internal {
        node.totalShares -= amount;
    }

    function _distributePublicPoolRewards(uint256 publicPoolRewards) internal returns (uint256) {
        // rewards for public pool
        uint256 tax = _getFullTax(publicPoolRewards, _publicPool.taxRateBasisPoints);

        _increaseStakingPool(_publicPool, publicPoolRewards - tax);

        return tax;
    }

    function _distributeNodesRewards(
        address[] memory nodeAddrs,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards
    ) internal returns (uint256[] memory taxCollected) {
        taxCollected = new uint256[](nodeAddrs.length);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node storage node = _nodes[nodeAddrs[i]];
            if (node.account == address(0) || node.publicGood || node.operationPoolTokens < MIN_DEPOSIT) {
                continue;
            }

            // operation rewards and staking rewards are sent to staking pool
            uint256 rewards = operationRewards[i] + stakingRewards[i];
            (uint256 fullTax, uint256 receivedTax) = _getTax(
                rewards,
                node.taxRateBasisPoints,
                node.operationPoolTokens,
                node.stakingPoolTokens
            );

            taxCollected[i] = receivedTax;

            // update node pool
            // receivedTax is sent to operation pool
            _increaseOperationPool(node, receivedTax);
            // all after-tax rewards are sent to the staking pool
            _increaseStakingPool(node, rewards - fullTax);
            // the remaining tax is sent to the treasury
        }
        return taxCollected;
    }

    /// @dev unstake from a node by burning chips
    function _unstakeFromNode(address nodeAddr, uint256[] calldata chipsIds) internal returns (uint256 requestId) {
        address owner = _checkChipsConditions(nodeAddr, chipsIds);

        DataTypes.Node storage node = _nodes[nodeAddr].publicGood ? _publicPool : _nodes[nodeAddr];

        requestId = ++_pendingUnstakeCounter;

        // update pool tokens and shares
        uint256 sharesToBurn;
        uint256 unstakeAmount;
        for (uint256 i = 0; i < chipsIds.length; i++) {
            (, uint256 amount, uint256 shares) = _chipsInfo(chipsIds[i]);
            unstakeAmount += amount;
            sharesToBurn += shares;
        }
        _decreaseStakingPool(node, unstakeAmount);
        _decreaseTotalShares(node, sharesToBurn);

        // add to request queue
        DataTypes.UnstakeRequest storage req = _pendingUnstake[requestId];
        req.timestamp = block.timestamp;
        req.owner = owner;

        req.nodeAddr = nodeAddr;
        req.unstakeAmount = unstakeAmount;

        // burn chips and reset corresponding shares
        for (uint256 i = 0; i < chipsIds.length; i++) {
            IChips(_chips).burn(chipsIds[i]);

            _chipToShares[chipsIds[i]] = 0;
        }

        emit Events.UnstakeRequested(owner, nodeAddr, requestId, unstakeAmount, chipsIds);
    }

    /// @dev create a node
    function _createNode(
        address nodeAddr,
        string calldata name,
        string calldata description,
        uint64 taxRateBasisPoints,
        bool publicGood
    ) internal {
        if (nodeAddr == address(0)) revert CreateNodeToZeroAddress();
        if (taxRateBasisPoints > _denominator()) revert TaxRateBasisPointsTooLarge();

        uint256 nodeId = ++_nodeIdCounter;

        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.nodeId > 0) revert NodeExists();
        node.nodeId = nodeId;
        node.account = nodeAddr;
        node.name = name;
        node.description = description;
        node.taxRateBasisPoints = taxRateBasisPoints;
        node.publicGood = publicGood;
        node.alpha = _isAlphaPhase;

        // add to node list
        _nodeAddrs.add(nodeAddr);

        emit Events.NodeCreated(nodeId, nodeAddr, name, description, taxRateBasisPoints, publicGood, _isAlphaPhase);
    }

    /// @dev deposit tokens to a node
    function _deposit(address nodeAddr, uint256 amount) internal {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert NodeNotExists();

        _increaseOperationPool(node, amount);

        emit Events.Deposited(nodeAddr, amount);
    }

    /// @dev stakes tokens to a node
    function _stakeToNode(
        DataTypes.Node storage node,
        uint256 amount,
        address nodeAddr
    ) internal returns (uint256 startTokenId, uint256 endTokenId) {
        if (amount == 0) revert StakeZeroAmount();

        uint256 sharesToMint = _tokensToShares(amount, nodeAddr);

        // update staking pool
        _increaseStakingPool(node, amount);
        // update pool shares
        _increaseTotalShares(node, sharesToMint);

        // mint chips
        (startTokenId, endTokenId) = IChips(_chips).mintBatch(msg.sender, 1);
        _chipIssuers[startTokenId] = nodeAddr;
        // set chip shares
        _chipToShares[endTokenId] = sharesToMint;

        emit Events.Staked(msg.sender, node.account, amount, startTokenId, endTokenId);
    }

    /// @dev claim unstake request
    function _claimUnstake(uint256 requestId) internal {
        DataTypes.UnstakeRequest memory req = _pendingUnstake[requestId];
        if (req.owner == address(0)) revert ClaimIdNotExists(requestId);

        if (block.timestamp < req.timestamp + STAKE_UNBONDING_PERIOD) revert ClaimTimeNotReady();

        delete _pendingUnstake[requestId];

        // transfer tokens
        _transfer(req.owner, req.unstakeAmount);

        emit Events.UnstakeClaimed(requestId, req.nodeAddr, req.owner, req.unstakeAmount);
    }

    /// @dev claim withdrawal request
    function _claimWithdrawal(uint256 requestId) internal {
        DataTypes.WithdrawalRequest memory req = _pendingWithdrawals[requestId];

        if (req.owner == address(0)) revert ClaimIdNotExists(requestId);
        if (block.timestamp < req.timestamp + DEPOSIT_UNBONDING_PERIOD) revert ClaimTimeNotReady();

        delete _pendingWithdrawals[requestId];

        // transfer tokens
        _transfer(req.owner, req.amount);

        emit Events.WithdrawalClaimed(requestId);
    }

    /// @dev transfer native tokens by a low-level call.
    /// _transfer should always be at the end of the function,
    /// to apply the checks-effects-interactions pattern
    function _transfer(address to, uint256 amount) internal {
        if (amount > 0) {
            (bool success, ) = address(to).call{value: amount}("");
            if (!success) revert TransferFailed();
        }
    }

    /// @dev returns whether user is token owner or approved
    function _isAuthorized(address owner, uint256 tokenId, address user) internal view returns (bool) {
        return
            owner == user ||
            IERC721(_chips).getApproved(tokenId) == user ||
            IERC721(_chips).isApprovedForAll(owner, user);
    }

    /// @dev checks that:
    /// 1. length of chipsIds is not zero
    /// 2. caller has the authorization to unstake the chips
    /// 3. chips are issued by the same node
    /// 4. chips have the same owner
    function _checkChipsConditions(address nodeAddr, uint256[] calldata chipIds) internal view returns (address) {
        if (chipIds.length == 0) revert EmptyChipsIds();

        address lastOwner;
        for (uint256 i = 0; i < chipIds.length; i++) {
            uint256 tokenId = chipIds[i];
            address owner = IERC721(_chips).ownerOf(tokenId);
            if (lastOwner != address(0) && owner != lastOwner) revert ChipsNotSameOwner();
            lastOwner = owner;

            if (!_isAuthorized(owner, tokenId, msg.sender)) revert ChipNotAuthorized(tokenId);

            if (_issuerOf(tokenId) != nodeAddr) revert ChipNotValid(tokenId, nodeAddr);
        }

        return lastOwner;
    }

    /// @dev returns the node address which issued the chips
    function _issuerOf(uint256 tokenId) internal view returns (address) {
        // check the token was not burned, and fetch ownership from the anchors
        // Note: no need for safe cast, we know that tokenId <= type(uint96).max
        address issuer = address(_families.lowerLookup(tokenId.toUint96()));
        return issuer != address(0) ? issuer : _chipIssuers[tokenId];
    }

    function _chipsInfo(uint256 tokenId) internal view returns (address nodeAddr, uint256 tokens, uint256 shares) {
        nodeAddr = _issuerOf(tokenId);

        shares = _chipToShares[tokenId];
        if (shares == 0) {
            // old chip is always:  1 token = SHARES_PER_CHIP shares
            shares = SHARES_PER_CHIP;
        }

        DataTypes.Node storage node = _nodes[nodeAddr].publicGood ? _publicPool : _nodes[nodeAddr];
        tokens = _sharesToTokens(shares, node.totalShares, node.stakingPoolTokens);
    }

    /**
     * @dev get tax amount
     *  For a node operator to receive its full tax,
     * it needs to stake at least 1/25 of the tokens staked by external delegators,
     * or the exceeding part of the tax will be sent to the staking pool.
     */
    function _getTax(
        uint256 rewards,
        uint64 taxRateBasisPoints,
        uint256 operationPool,
        uint256 stakingPool
    ) internal view returns (uint256, uint256) {
        uint256 fullTax = _getFullTax(rewards, taxRateBasisPoints);

        if (operationPool < MIN_DEPOSIT) {
            // node will receive no tax
            return (fullTax, 0);
        } else if (operationPool >= MIN_DEPOSIT && operationPool * STAKE_RATIO >= stakingPool) {
            // node will receive its full tax
            return (fullTax, fullTax);
        } else {
            // node will receive part of its tax
            uint256 partialTax = (fullTax * operationPool * STAKE_RATIO) / stakingPool;
            return (fullTax, partialTax);
        }
    }

    /// @dev convert tokens to equivalent shares
    function _tokensToShares(uint256 tokens, address nodeAddr) internal view returns (uint256) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.publicGood) {
            node = _publicPool;
        }

        if (node.stakingPoolTokens == 0) {
            return tokens;
        }

        return (tokens * node.totalShares) / node.stakingPoolTokens;
    }

    /// @dev returns the full tax amount
    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints) internal pure returns (uint256) {
        return (rewards * taxRateBasisPoints) / _denominator();
    }

    /// @dev convert shares to equivalent tokens
    function _sharesToTokens(uint256 shares, uint256 totalShares, uint256 totalTokens) internal pure returns (uint256) {
        return totalShares == 0 ? 0 : (shares * totalTokens) / totalShares;
    }

    /**
     * @dev denominator
     */
    function _denominator() internal pure virtual returns (uint64) {
        return 10000;
    }
}
