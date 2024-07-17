// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore
pragma solidity 0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {DataTypes} from "../libraries/DataTypes.sol";

contract StakingStorage {
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
    Checkpoints.Trace160 internal _families; // for compatibility with the previous version
    mapping(uint256 chipId => address nodeAddr) internal _chipIssuers;

    /// @dev shares corresponding to each chip
    mapping(uint256 chipId => uint256 shares) internal _chipToShares;

    /// ACL
    bytes32 public constant PAUSE_ROLE = keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 public immutable SLASH_REPORTER_BONUS_RATE_BASIS_POINTS;

    uint256 internal _totalSlashingPoolTokens;

    /// @dev (nodeAddr, epochId) => slash record
    mapping(address nodeAddr => mapping(uint256 epochId => DataTypes.SlashRecord)) internal _slashRecords;

    constructor(
        address treasury,
        uint256 stakeRatio,
        uint256 stakeUnbondingPeriod,
        uint256 depositUnbondingPeriod,
        uint256 nodeSlashRateBasisPoints,
        uint256 userSlashRateBasisPoints,
        uint256 minDeposit,
        uint256 minTaxRateBasisPoints,
        uint256 slashReporterBonusRateBasisPoints
    ) {
        TREASURY = treasury;
        STAKE_RATIO = stakeRatio;

        STAKE_UNBONDING_PERIOD = stakeUnbondingPeriod;
        DEPOSIT_UNBONDING_PERIOD = depositUnbondingPeriod;

        NODE_SLASH_RATE_BASIS_POINTS = nodeSlashRateBasisPoints;
        USER_SLASH_RATE_BASIS_POINTS = userSlashRateBasisPoints;

        MIN_DEPOSIT = minDeposit;
        MIN_TAX_RATE_BASIS_POINTS = minTaxRateBasisPoints;

        SLASH_REPORTER_BONUS_RATE_BASIS_POINTS = slashReporterBonusRateBasisPoints;
    }
}
