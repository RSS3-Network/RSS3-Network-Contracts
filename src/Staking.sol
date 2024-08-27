// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore
pragma solidity 0.8.20;

import {IStaking} from "./interfaces/IStaking.sol";
import {IChips} from "./interfaces/IChips.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Events} from "./libraries/Events.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {StorageLib} from "./libraries/StorageLib.sol";
import {RewardsAndSlashingLib} from "./libraries/RewardsAndSlashingLib.sol";
import {NodeSettingsLib} from "./libraries/NodeSettingsLib.sol";
import {StakingLib} from "./libraries/StakingLib.sol";
import {
    InsufficientValue,
    PublicGoodNodeNotDeposited,
    PublicGoodNodeTaxNotZero,
    NodeNotExists,
    TaxRateBasisPointsTooSmall,
    ExcessWithdrawalAmount,
    InvalidArrayLength,
    SettlementPhase,
    StakeToPublicGoodNode,
    NodeNotPublicGood,
    TransferFailed
} from "./libraries/Errors.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable, ReentrancyGuard {
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

    /// @dev the payment processor receives slashing tax
    address public immutable PAYMENT_PROCESSOR;

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
    Checkpoints.Trace160 internal _families; // for compatibility with the previous version
    mapping(uint256 chipId => address nodeAddr) internal _chipIssuers;

    /// @dev shares corresponding to each chip
    mapping(uint256 chipId => uint256 shares) internal _chipToShares;

    /// ACL
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 internal _totalSlashingPoolTokens;

    /// @dev (nodeAddr, epochId) => slash record
    mapping(address nodeAddr => mapping(uint256 epochId => DataTypes.SlashRecord)) internal _slashRecords;

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
     * @param minTaxRateBasisPoints The minimal tax rate basis points.
     */
    constructor(
        address treasury,
        uint256 stakeRatio,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        uint256 nodeSlashRateBasisPoints,
        uint256 userSlashRateBasisPoints,
        uint256 minDeposit,
        uint256 minTaxRateBasisPoints,
        address paymentProcessor
    ) {
        TREASURY = treasury;
        STAKE_RATIO = stakeRatio;
        STAKE_UNBONDING_PERIOD = stakeUnbondingPeriod;
        DEPOSIT_UNBONDING_PERIOD = depositUnbondingPeriod;
        NODE_SLASH_RATE_BASIS_POINTS = nodeSlashRateBasisPoints;
        USER_SLASH_RATE_BASIS_POINTS = userSlashRateBasisPoints;
        MIN_DEPOSIT = minDeposit;
        MIN_TAX_RATE_BASIS_POINTS = minTaxRateBasisPoints;
        PAYMENT_PROCESSOR = paymentProcessor;
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
        if (msg.value == 0) revert InsufficientValue();
        StakingLib.deposit(msg.sender, msg.value);
    }

    /// @inheritdoc IStaking
    function requestWithdrawal(uint256 amount) external override whenNotPaused returns (uint256 requestId) {
        DataTypes.Node storage node = _nodes[msg.sender];
        if (node.account == address(0)) revert NodeNotExists();

        //  withdrawal amount should not exceed the operation pool tokens
        if (amount > node.operationPoolTokens) revert ExcessWithdrawalAmount();

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
        DataTypes.Node storage node = _nodes[nodeAddr];
        // validate node
        if (node.account == address(0)) revert NodeNotExists();
        if (node.publicGood) revert StakeToPublicGoodNode(nodeAddr);

        tokenId = StakingLib.stakeToNode(node, msg.value, nodeAddr, msg.sender, SHARES_PER_CHIP);
    }

    /// @inheritdoc IStaking
    function stakeToPublicPool(
        address nodeAddr
    ) external payable override whenNotPaused whenNotSettlementPhase returns (uint256 tokenId) {
        DataTypes.Node storage node = _nodes[nodeAddr];
        if (node.account == address(0)) revert NodeNotExists();
        if (!node.publicGood) revert NodeNotPublicGood(nodeAddr);

        tokenId = StakingLib.stakeToNode(_publicPool, msg.value, nodeAddr, msg.sender, SHARES_PER_CHIP);
    }

    /// @inheritdoc IStaking
    function requestUnstake(
        address nodeAddr,
        uint256[] calldata chipIds
    ) external override whenNotPaused whenNotSettlementPhase returns (uint256 requestId) {
        return StakingLib.unstakeFromNode(nodeAddr, chipIds, SHARES_PER_CHIP);
    }

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused nonReentrant {
        for (uint256 i = 0; i < requestIds.length; i++) {
            StakingLib.claimUnstake(requestIds[i], STAKE_UNBONDING_PERIOD);
        }
    }

    /// @inheritdoc IStaking
    function setTaxRateBasisPoints4Node(uint64 taxRateBasisPoints) external override whenNotPaused {
        NodeSettingsLib.setTaxRateBasisPoints4Node(taxRateBasisPoints, MIN_TAX_RATE_BASIS_POINTS, msg.sender);
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
            stakingRewards,
            MIN_DEPOSIT,
            STAKE_RATIO
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
        return StakingLib.mergeChips(chipIds, SHARES_PER_CHIP);
    }

    /// @inheritdoc IStaking
    function recordSlashing(
        DataTypes.Slashing[] calldata slashings,
        address[] calldata reporters,
        string[] calldata reasons
    ) external override whenNotPaused onlyRole(ORACLE_ROLE) {
        if (slashings.length != reporters.length) revert InvalidArrayLength();
        if (slashings.length != reasons.length) revert InvalidArrayLength();

        for (uint256 i = 0; i < slashings.length; i++) {
            (address nodeAddr, uint256 epoch) = (slashings[i].nodeAddr, slashings[i].epoch);
            address reporter = reporters[i];
            string calldata reason = reasons[i];

            RewardsAndSlashingLib.recordSlashing(
                nodeAddr,
                epoch,
                reporter,
                reason,
                NODE_SLASH_RATE_BASIS_POINTS,
                USER_SLASH_RATE_BASIS_POINTS
            );
        }
    }

    /// @inheritdoc IStaking
    function commitSlashing(
        DataTypes.Slashing[] calldata slashings
    ) external override whenNotPaused onlyRole(ORACLE_ROLE) {
        for (uint256 i = 0; i < slashings.length; i++) {
            (address nodeAddr, uint256 epoch) = (slashings[i].nodeAddr, slashings[i].epoch);

            RewardsAndSlashingLib.commitSlashing(nodeAddr, epoch, PAYMENT_PROCESSOR);
        }
    }

    /// @inheritdoc IStaking
    function revokeSlashing(
        DataTypes.Slashing[] calldata slashings
    ) external override whenNotPaused onlyRole(ORACLE_ROLE) {
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
    function disableAlphaPhase() external override whenNotPaused onlyRole(ORACLE_ROLE) {
        _isAlphaPhase = false;
    }

    /// @inheritdoc IStaking
    function withdraw2Treasury() external override {
        uint256 balance = address(this).balance;
        uint256 amount = balance - _totalOperationPoolTokens - _totalStakingPoolTokens - _totalSlashingPoolTokens;
        RewardsAndSlashingLib.withdraw2Treasury(TREASURY, amount);
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
    function getChipInfo(
        uint256 tokenId
    ) external view override returns (address nodeAddr, uint256 tokens, uint256 shares) {
        (nodeAddr, tokens, shares) = StakingLib.getChipInfo(tokenId, SHARES_PER_CHIP);
    }

    function getSlashingRecords(
        DataTypes.Slashing[] calldata slashings
    ) external view override returns (DataTypes.SlashRecord[] memory records) {
        records = new DataTypes.SlashRecord[](slashings.length);
        for (uint256 i = 0; i < slashings.length; i++) {
            records[i] = StorageLib.getSlashRecord(slashings[i].nodeAddr, slashings[i].epoch);
        }
    }

    /// @inheritdoc IStaking
    function getPublicPool() external pure override returns (DataTypes.Node memory) {
        return StorageLib.publicPool();
    }

    /// @inheritdoc IStaking
    function getNodeCount() external view override returns (uint256) {
        return StorageLib.nodeAddrs().length();
    }

    /// @inheritdoc IStaking
    function getNode(address nodeAddr) external view override returns (DataTypes.Node memory) {
        return StorageLib.nodes()[nodeAddr];
    }

    /// @inheritdoc IStaking
    function getNodeAvatar(address nodeAddr) external view override returns (string memory) {
        return IChips(_chips).nodeImageAndAttributesURI(nodeAddr);
    }

    /// @inheritdoc IStaking
    function getNodes(address[] calldata nodeAddrs) external view override returns (DataTypes.Node[] memory nodes) {
        nodes = new DataTypes.Node[](nodeAddrs.length);
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            nodes[i] = StorageLib.nodes()[nodeAddrs[i]];
        }
    }

    /// @inheritdoc IStaking
    function getNodesWithPagination(
        uint256 offset,
        uint256 limit
    ) external view override returns (DataTypes.Node[] memory nodes) {
        uint256 totalNodes = StorageLib.nodeAddrs().length();
        uint256 len = (totalNodes - offset).min(limit);
        nodes = new DataTypes.Node[](len);

        if (offset >= totalNodes) return nodes;

        for (uint256 i = offset; i < len + offset; i++) {
            address nodeAddr = StorageLib.nodeAddrs().at(i);
            nodes[i - offset] = StorageLib.nodes()[nodeAddr];
        }
    }

    /// @inheritdoc IStaking
    function getPoolInfo()
        external
        view
        override
        returns (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens, uint256 totalSlashingPoolTokens)
    {
        totalOperationPoolTokens = _totalOperationPoolTokens;
        totalStakingPoolTokens = _totalStakingPoolTokens;
        totalSlashingPoolTokens = _totalSlashingPoolTokens;
    }

    /// @inheritdoc IStaking
    function chipsContract() external view override returns (address) {
        return StorageLib.getChipsContract();
    }
}
