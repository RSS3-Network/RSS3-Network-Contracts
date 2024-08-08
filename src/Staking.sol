// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore
pragma solidity 0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IChips} from "./interfaces/IChips.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {Const} from "./libraries/Const.sol";
import {
    Node,
    NodeObsoleted,
    NodeStatus,
    Slashing,
    SlashRecord,
    WithdrawalRequest,
    UnstakeRequest,
    PoolStatData
} from "./libraries/DataTypes.sol";
import {
    AlphaWithdrawNotAllowed,
    NodeNotExists,
    ExcessWithdrawalAmount,
    WithdrawalAmountExceedsOperationPoolTokens,
    InvalidArrayLength,
    SettlementPhase,
    StakeToPublicGoodNode,
    NodeNotPublicGood
} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";
import {NodeSettingsLib} from "./libraries/NodeSettingsLib.sol";
import {RewardsAndSlashingLib} from "./libraries/RewardsAndSlashingLib.sol";
import {StakingLib} from "./libraries/StakingLib.sol";
import {StorageLib} from "./libraries/StorageLib.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable, ReentrancyGuard {
    using Math for uint256;
    using SafeCast for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Checkpoints for Checkpoints.Trace160;

    string public constant version = "2.0.0";

    /// @dev the treasury receives all unqualified rewards, e.g. the exceeding part of the tax
    address public immutable TREASURY;

    /// @dev the payment processor receives slashing tax
    address public immutable PAYMENT_PROCESSOR;

    /// @dev the period of time that node operator can't withdraw staked tokens
    uint256 public immutable DEPOSIT_UNBONDING_PERIOD;
    /// @dev the period of time that user can't withdraw staked tokens
    uint256 public immutable STAKE_UNBONDING_PERIOD;

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
    mapping(address nodeAddr => Node node) internal _nodes;
    /// @dev counter of node id
    uint256 internal _nodeIdCounter;

    /// @dev pending withdrawal request counter
    uint256 internal _pendingWithdrawalCounter;
    /// @dev pending withdrawal request
    mapping(uint256 requestId => WithdrawalRequest request) internal _pendingWithdrawals;

    /// @dev unstake request queue counter
    uint256 internal _pendingUnstakeCounter;
    /// @dev unstake request queue
    mapping(uint256 requestId => UnstakeRequest request) internal _pendingUnstake;

    /// @dev old public pool
    NodeObsoleted internal _oldPublicPool;

    /// @dev total operation pool tokens
    uint256 internal _totalOperationPoolTokens; // deprecated in next version
    /// @dev total staking pool tokens
    uint256 internal _totalStakingPoolTokens; // deprecated in next version

    /// @dev the issuers of chips
    Checkpoints.Trace160 internal _families; // for compatibility with the previous version
    mapping(uint256 chipId => address nodeAddr) internal _chipIssuers;

    /// @dev shares corresponding to each chip
    mapping(uint256 chipId => uint256 shares) internal _chipToShares;

    /// ACL
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 internal _totalSlashingPoolTokens; // deprecated in next version

    /// @dev (nodeAddr, epochId) => slash record
    mapping(address nodeAddr => mapping(uint256 epochId => SlashRecord)) internal _slashRecords;

    mapping(uint256 epoch => mapping(address nodeAddr => uint256 count)) internal _nodeDemotionCounter; // slot 28

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
     * @param stakeUnbondingPeriod Time in seconds user need to wait to unstake its stake.
     * @param depositUnbondingPeriod Time in seconds node operator need to wait to withdraw its deposit.
     * @param paymentProcessor The address of payment processor contract.
     */
    constructor(
        address treasury,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        address paymentProcessor
    ) {
        TREASURY = treasury;

        STAKE_UNBONDING_PERIOD = stakeUnbondingPeriod;
        DEPOSIT_UNBONDING_PERIOD = depositUnbondingPeriod;

        PAYMENT_PROCESSOR = paymentProcessor;
    }

    /// @inheritdoc IStaking
    function initialize(address chips, address pauseAccount, address oracleAccount) external override reinitializer(2) {
        if (chips != address(0)) {
            _chips = chips;
        }

        if (pauseAccount != address(0)) {
            _grantRole(PAUSE_ROLE, pauseAccount);
        }

        if (oracleAccount != address(0)) {
            _grantRole(ORACLE_ROLE, oracleAccount);
        }

        _isAlphaPhase = true;

        /// TODO: should be removed in next version
        // migrate public pool
        _migratePublicPool();
        // migrate pool stat info
        _migratePoolStatInfo();
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
        NodeSettingsLib.createNode(msg.sender, name, description, taxRateBasisPoints, publicGood);

        if (msg.value > 0) {
            StakingLib.deposit(msg.sender, msg.value);
        }
    }

    /// @inheritdoc IStaking
    function updateNode(string calldata name, string calldata description) external override whenNotPaused {
        NodeSettingsLib.updateNode(msg.sender, name, description);
    }

    /// @inheritdoc IStaking
    function deposit() external payable override whenNotPaused {
        if (msg.value > 0) {
            StakingLib.deposit(msg.sender, msg.value);
        }
    }

    /// @inheritdoc IStaking
    function requestWithdrawal(
        uint256 amount
    ) external override whenNotPaused whenNotAlphaPhase returns (uint256 requestId) {
        Node storage node = _nodes[msg.sender];
        _validateNodeAddress(node.account);

        //  withdrawal amount should not exceed the operation pool tokens
        if (amount > node.operationPoolTokens) revert WithdrawalAmountExceedsOperationPoolTokens();

        // deposit balance must >= MIN_DEPOSIT when node is not in `Exited` status
        NodeStatus status = NodeSettingsLib.getNodeStatus(node);
        if (NodeStatus.Exited != status && node.operationPoolTokens - amount < Const.MIN_DEPOSIT)
            revert ExcessWithdrawalAmount();

        return StakingLib.requestWithdrawal(node, amount);
    }

    /// @inheritdoc IStaking
    function claimWithdrawal(uint256[] calldata requestIds) external override whenNotPaused nonReentrant {
        for (uint256 i = 0; i < requestIds.length; i++) {
            StakingLib.claimWithdrawal(requestIds[i], DEPOSIT_UNBONDING_PERIOD);
        }
    }

    /// @inheritdoc IStaking
    function stake(
        address nodeAddr
    ) external payable override whenNotPaused whenNotSettlementPhase returns (uint256 tokenId) {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (node.publicGood) revert StakeToPublicGoodNode(nodeAddr);
        if (node.account == address(0)) revert NodeNotExists();

        // node should not in exit status
        NodeSettingsLib._validateNodeNotInExitStatus(node);

        tokenId = StakingLib.stakeToNode(node, msg.value, nodeAddr, msg.sender);
    }

    /// @inheritdoc IStaking
    function stakeToPublicPool(
        address nodeAddr
    ) external payable override whenNotPaused whenNotSettlementPhase returns (uint256 tokenId) {
        Node storage node = StorageLib.getNode(nodeAddr);
        if (!node.publicGood) revert NodeNotPublicGood(nodeAddr);

        // node should not in exit status
        NodeSettingsLib._validateNodeNotInExitStatus(node);

        tokenId = StakingLib.stakeToNode(StorageLib.publicPool(), msg.value, nodeAddr, msg.sender);
    }

    /// @inheritdoc IStaking
    function requestUnstake(
        address nodeAddr,
        uint256[] calldata chipIds
    ) external override whenNotPaused whenNotSettlementPhase whenNotAlphaPhase returns (uint256 requestId) {
        return StakingLib.unstakeFromNode(nodeAddr, chipIds);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused nonReentrant {
        for (uint256 i = 0; i < requestIds.length; i++) {
            StakingLib.claimUnstake(requestIds[i], STAKE_UNBONDING_PERIOD);
        }
    }

    /// @inheritdoc IStaking
    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints) external override whenNotPaused {
        NodeSettingsLib.setTaxRateBasisPoints4Node(taxRateBasisPoints, msg.sender);
    }

    /// @inheritdoc IStaking
    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external override onlyRole(ORACLE_ROLE) {
        NodeSettingsLib.setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
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
            uint256 tax = RewardsAndSlashingLib.distributePublicPoolRewards(publicPoolRewards);
            emit Events.PublicGoodRewardDistributed(epochInfo[0], epochInfo[1], epochInfo[2], publicPoolRewards, tax);
        }

        // distribute rewards for other nodes
        uint256[] memory taxCollected = RewardsAndSlashingLib.distributeNodesRewards(
            nodeAddrs,
            operationRewards,
            stakingRewards
        );

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
    function mergeChips(uint256[] calldata chipIds) external override returns (uint256 newTokenId) {
        return StakingLib.mergeChips(chipIds);
    }

    /// @inheritdoc IStaking
    function recordSlashing(
        Slashing[] calldata slashings,
        address[] calldata reporters,
        string[] calldata reasons
    ) external override whenNotPaused onlyRole(ORACLE_ROLE) {
        if (slashings.length != reporters.length) revert InvalidArrayLength();
        if (slashings.length != reasons.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < slashings.length; i++) {
            (address nodeAddr, uint256 epoch) = (slashings[i].nodeAddr, slashings[i].epoch);
            address reporter = reporters[i];
            string calldata reason = reasons[i];

            RewardsAndSlashingLib.recordSlashing(nodeAddr, epoch, reporter, reason);
        }
    }

    /// @inheritdoc IStaking
    function commitSlashing(Slashing[] calldata slashings) external override whenNotPaused onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < slashings.length; i++) {
            (address nodeAddr, uint256 epoch) = (slashings[i].nodeAddr, slashings[i].epoch);

            RewardsAndSlashingLib.commitSlashing(nodeAddr, epoch, PAYMENT_PROCESSOR);
        }
    }

    /// @inheritdoc IStaking
    function revokeSlashing(Slashing[] calldata slashings) external override whenNotPaused onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < slashings.length; i++) {
            (address nodeAddr, uint256 epoch) = (slashings[i].nodeAddr, slashings[i].epoch);

            RewardsAndSlashingLib.revokeSlashing(nodeAddr, epoch);
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
    function setNodeStatus(
        address[] calldata nodeAddrs,
        NodeStatus[] calldata status
    ) external override onlyRole(ORACLE_ROLE) {
        NodeSettingsLib.setNodesStatus(nodeAddrs, status);
    }

    /// @inheritdoc IStaking
    function demoteNodes(
        uint256 epoch,
        address[] calldata nodeAddrs,
        string[] calldata reasons
    ) external override onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != reasons.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];

            if (++_nodeDemotionCounter[epoch][nodeAddr] >= Const.DEMOTION_COUNT_THRESHOLD) {
                // check node status
                NodeStatus status = NodeSettingsLib.getNodeStatus(StorageLib.getNode(nodeAddr));
                if (status != NodeStatus.Slashing) {
                    // slash
                    RewardsAndSlashingLib.recordSlashing(nodeAddr, epoch, address(0), Const.DEFAULT_SLASH_REASON);
                }
            }

            emit Events.NodeDemoted(epoch, nodeAddr, _nodeDemotionCounter[epoch][nodeAddr], reasons[i]);
        }
    }

    /// @inheritdoc IStaking
    function requestExit() external override whenNotPaused {
        NodeSettingsLib.requestExit(msg.sender);
    }

    /// @inheritdoc IStaking
    function reRegister() external override whenNotPaused {
        NodeSettingsLib.reRegister(msg.sender);
    }

    /// @inheritdoc IStaking
    function withdraw2Treasury() external override {
        PoolStatData storage pool = StorageLib.poolStatStorage();

        uint256 amount = address(this).balance -
            pool.totalOperationPoolTokens -
            pool.totalStakingPoolTokens -
            pool.totalSlashingPoolTokens;
        RewardsAndSlashingLib.withdraw2Treasury(TREASURY, amount);
    }

    /// @inheritdoc IStaking
    function getDemotionCount(uint256 epoch, address nodeAddr) external view override returns (uint256) {
        return _nodeDemotionCounter[epoch][nodeAddr];
    }

    /// @inheritdoc IStaking
    function isSettlementPhase() external view override returns (bool) {
        return _isSettlementPhase;
    }

    /// @inheritdoc IStaking
    function isAlphaPhase() external view override returns (bool) {
        return StorageLib.getIsAlphaPhase();
    }

    /// @inheritdoc IStaking
    function getPendingWithdrawal(uint256 requestId) external view override returns (WithdrawalRequest memory) {
        return _pendingWithdrawals[requestId];
    }

    /// @inheritdoc IStaking
    function getPendingUnstake(uint256 requestId) external view override returns (UnstakeRequest memory) {
        return _pendingUnstake[requestId];
    }

    /// @inheritdoc IStaking
    function getChipInfo(
        uint256 tokenId
    ) external view override returns (address nodeAddr, uint256 tokens, uint256 shares) {
        (nodeAddr, tokens, shares) = StakingLib.getChipInfo(tokenId);
    }

    /// @inheritdoc IStaking
    function getNodeCount() external view override returns (uint256) {
        return StorageLib.nodeAddrs().length();
    }

    /// @inheritdoc IStaking
    function getNodeAvatar(address nodeAddr) external view override returns (string memory) {
        return IChips(_chips).nodeImageAndAttributesURI(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getPoolInfo()
        external
        view
        override
        returns (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens, uint256 totalSlashingPoolTokens)
    {
        PoolStatData storage pool = StorageLib.poolStatStorage();

        totalOperationPoolTokens = pool.totalOperationPoolTokens;
        totalStakingPoolTokens = pool.totalStakingPoolTokens;
        totalSlashingPoolTokens = pool.totalSlashingPoolTokens;
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (Node memory) {
        Node memory node = StorageLib.getNode(nodeAddr);
        node.status = NodeSettingsLib.getNodeStatus(node);
        return node;
    }

    /// @inheritdoc IStaking
    function getNodes(address[] calldata nodeAddrs) external view override returns (Node[] memory nodes) {
        nodes = new Node[](nodeAddrs.length);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            address nodeAddr = nodeAddrs[i];

            nodes[i] = StorageLib.getNode(nodeAddr);
            nodes[i].status = NodeSettingsLib.getNodeStatus(nodes[i]);
        }
    }

    /// @inheritdoc IStaking
    function chipsContract() external view override returns (address) {
        return StorageLib.getChipsContract();
    }

    /// @inheritdoc IStaking
    function getSlashingRecords(
        Slashing[] calldata slashings
    ) external pure override returns (SlashRecord[] memory records) {
        records = new SlashRecord[](slashings.length);
        for (uint256 i = 0; i < slashings.length; i++) {
            records[i] = StorageLib.getSlashRecord(slashings[i].nodeAddr, slashings[i].epoch);
        }
    }

    /// @inheritdoc IStaking
    function getPublicPool() external pure override returns (Node memory) {
        return StorageLib.publicPool();
    }

    function _migratePublicPool() internal {
        Node storage pp = StorageLib.publicPool();
        pp.taxRateBasisPoints = _oldPublicPool.taxRateBasisPoints;
        pp.publicGood = true;
        pp.name = "Public Good Pool";
        pp.operationPoolTokens = _oldPublicPool.operationPoolTokens;
        pp.stakingPoolTokens = _oldPublicPool.stakingPoolTokens;
        pp.totalShares = _oldPublicPool.totalShares;

        delete _oldPublicPool.taxRateBasisPoints;
        delete _oldPublicPool.operationPoolTokens;
        delete _oldPublicPool.stakingPoolTokens;
        delete _oldPublicPool.totalShares;
    }

    function _migratePoolStatInfo() internal {
        PoolStatData storage pool = StorageLib.poolStatStorage();
        pool.totalOperationPoolTokens = _totalOperationPoolTokens;
        pool.totalStakingPoolTokens = _totalStakingPoolTokens;
        pool.totalSlashingPoolTokens = _totalSlashingPoolTokens;

        delete _totalOperationPoolTokens;
        delete _totalStakingPoolTokens;
        delete _totalSlashingPoolTokens;
    }

    function _validateNodeAddress(address nodeAddr) internal pure {
        if (nodeAddr == address(0)) revert NodeNotExists();
    }
}
