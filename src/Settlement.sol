// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ISettlement} from "./interfaces/ISettlement.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {Const} from "./libraries/Const.sol";
import {NodeStatus, RewardsData} from "./libraries/DataTypes.sol";
import {
    CommitEpochNotElapsed,
    InvalidArrayLength,
    InvalidEpochNumber,
    OperationRewardsExceed,
    RewardsAlreadyDistributed,
    SubmissionIntervalNotElapsed
} from "./libraries/Errors.sol";
import {AccessControlEnumerable} from
    "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract Settlement is ISettlement, Multicall, Initializable, AccessControlEnumerable {
    using Math for uint256;
    using SafeCast for uint256;

    string public constant version = "2.0.0";

    /// @dev Duration of an epoch.
    uint256 public constant EPOCH_DURATION = 18 hours;

    /// @dev Total rewards of the first year.
    uint256 public constant TOTAL_REWARDS_PER_YEAR = 30000000 * 10 ** 18;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    /// @dev Whether to check the epoch interval when updating the epoch.
    bool public immutable CHECK_EPOCH_INTERVAL;

    /// @dev Staking contract address.
    address internal _staking;

    uint256 internal _totalStakingRewardsPerEpoch;
    uint256 internal _totalOperationRewardsPerEpoch;

    /// @dev The current epoch.
    uint256 internal _currentEpoch;

    uint256 internal _startTimestamp;
    uint256 internal _endTimestamp;

    // total staking for each epoch
    mapping(uint256 epoch => uint256 totalStaking) internal _totalStakingSnapshot;
    // distributed operation rewards for each epoch
    mapping(uint256 epoch => uint256 operationRewards) internal _distributedOperationRewards;
    // rewarded node addresses
    mapping(uint256 epoch => mapping(address nodeAddr => bool rewarded)) internal _rewardedAddresses;

    modifier validEpoch(uint256 epoch) {
        if (epoch < _currentEpoch || epoch > _currentEpoch + 1) {
            revert InvalidEpochNumber(_currentEpoch, epoch);
        }
        _;
    }

    /**
     * @notice constructor.
     * @param checkEpochInterval Whether to check the epoch interval when updating the epoch.
     */
    constructor(bool checkEpochInterval) {
        CHECK_EPOCH_INTERVAL = checkEpochInterval;
    }

    // solhint-disable-next-line comprehensive-interface
    receive() external payable {}

    /// @inheritdoc ISettlement
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 operationRewardsPercent
    ) external override reinitializer(5) {
        if (staking != address(0)) {
            _staking = staking;
        }

        // grants `ORACLE_ROLE`
        if (oracleAccount != address(0)) {
            _grantRole(ORACLE_ROLE, oracleAccount);
        }

        if (startTime > 0) {
            _startTimestamp = startTime;
        }

        _updateRewardsRatio(operationRewardsPercent);
    }

    /// @inheritdoc ISettlement
    function distributeRewards(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata requestCounts,
        bool isFinal
    ) external override onlyRole(ORACLE_ROLE) validEpoch(epoch) {
        if (nodeAddrs.length != operationRewards.length || nodeAddrs.length != requestCounts.length)
        {
            revert InvalidArrayLength();
        }

        /// @dev we use a temp struct here to avoid `stack too deep`
        RewardsData memory data = _prepareRewardsData(epoch, nodeAddrs, operationRewards);

        // if it's the final distribution of the epoch, should set the phase to false
        IStaking(_staking).setSettlementPhase(!isFinal);

        // distribute rewards
        IStaking(_staking).distributeRewards{value: data.rewardsToSend}(
            data.epochInfo,
            nodeAddrs,
            operationRewards,
            data.stakingRewards,
            requestCounts,
            data.publicPoolRewards
        );
    }

    /// @inheritdoc ISettlement
    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints)
        external
        override
        onlyRole(ORACLE_ROLE)
    {
        IStaking(_staking).setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
    }

    /// @inheritdoc ISettlement
    function submitDemotions(
        address[] calldata nodeAddrs,
        string[] calldata reasons,
        address[] calldata reporters
    ) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).submitDemotions(_currentEpoch, nodeAddrs, reasons, reporters);
    }

    /// @inheritdoc ISettlement
    function revokeDemotions(address nodeAddr, uint256 epoch, uint256[] calldata demotionIds)
        external
        override
        onlyRole(ORACLE_ROLE)
    {
        IStaking(_staking).revokeDemotions(nodeAddr, epoch, demotionIds);
    }

    /// @inheritdoc ISettlement
    function commitSlashing(address[] calldata nodeAddrs, uint256[] calldata epochs)
        external
        override
        onlyRole(ORACLE_ROLE)
    {
        if (nodeAddrs.length != epochs.length) {
            revert InvalidArrayLength();
        }

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            if (_currentEpoch < epochs[i] + Const.SLASHING_COMMIT_PERIOD_IN_EPOCH) {
                revert CommitEpochNotElapsed(epochs[i], _currentEpoch);
            }

            IStaking(_staking).commitSlashing(nodeAddrs[i], epochs[i]);
        }
    }

    /// @inheritdoc ISettlement
    function setNodeStatus(address[] calldata nodeAddrs, NodeStatus[] calldata status)
        external
        override
        onlyRole(ORACLE_ROLE)
    {
        IStaking(_staking).setNodeStatus(nodeAddrs, status);
    }

    /// @inheritdoc ISettlement
    function stakingContract() external view override returns (address) {
        return _staking;
    }

    /// @inheritdoc ISettlement
    function currentEpoch() external view override returns (uint256) {
        return _currentEpoch;
    }

    /// @inheritdoc ISettlement
    function getBonusInfo() external view override returns (uint256, uint256) {
        return (_totalOperationRewardsPerEpoch, _totalStakingRewardsPerEpoch);
    }

    function _updateRewardsRatio(uint256 operationRewardsPercent) internal {
        _totalOperationRewardsPerEpoch =
            (TOTAL_REWARDS_PER_YEAR * EPOCH_DURATION * operationRewardsPercent) / (100 * 365 days);
        _totalStakingRewardsPerEpoch = (
            (TOTAL_REWARDS_PER_YEAR * EPOCH_DURATION) * (100 - operationRewardsPercent)
        ) / (100 * 365 days);
    }

    /// @dev check distributed operationRewards not exceeds the max rewards per
    /// epoch
    function _checkRewards(
        uint256 epoch,
        address[] memory nodeAddrs,
        uint256[] memory operationRewards
    ) internal {
        uint256 distributedOperationRewards = _distributedOperationRewards[epoch];
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            // check if the node has been rewarded
            if (_isRewarded(epoch, nodeAddrs[i])) revert RewardsAlreadyDistributed(nodeAddrs[i]);
            _rewardedAddresses[epoch][nodeAddrs[i]] = true;

            distributedOperationRewards += operationRewards[i];
        }

        // check if the distributed operation rewards exceeds the max rewards per epoch
        if (distributedOperationRewards > _totalOperationRewardsPerEpoch) {
            revert OperationRewardsExceed();
        }

        _distributedOperationRewards[epoch] = distributedOperationRewards;
    }

    /**
     * @dev Updates the epoch information.
     * @param epoch The new epoch number to set.
     *
     * This function performs the following tasks:
     * 1. Updates the current epoch to the provided epoch number.
     * 2. Updates the epoch timestamps:
     *    - Sets the start timestamp to the previous end timestamp (if it exists).
     *    - Sets the end timestamp to the current block timestamp.
     * 3. If CHECK_EPOCH_INTERVAL is true, it checks if the submission interval has elapsed:
     *    - The submission interval is defined as EPOCH_DURATION minus 1 hour.
     *    - If the time between start and end timestamps is less than or equal to the submission
     * interval,
     *      it reverts with a SubmissionIntervalNotElapsed error.
     */
    function _updateEpochInfo(uint256 epoch) internal {
        // update current epoch
        _currentEpoch = epoch;

        // update epoch timestamp
        if (_endTimestamp > 0) {
            _startTimestamp = _endTimestamp;
        }
        _endTimestamp = block.timestamp;

        // check epoch interval
        if (CHECK_EPOCH_INTERVAL) {
            uint256 submissionInterval = EPOCH_DURATION - 1 hours;
            if (_endTimestamp - _startTimestamp <= submissionInterval) {
                revert SubmissionIntervalNotElapsed();
            }
        }
    }

    /**
     * @dev Prepares the rewards data for distribution.
     * @param epoch The epoch number for which rewards are being prepared.
     * @param nodeAddrs An array of node addresses to receive rewards.
     * @param operationRewards An array of operation rewards corresponding to each node address.
     * @return data A RewardsData struct containing the prepared rewards information.
     *
     * This function performs the following tasks:
     * 1. Checks and updates the operation rewards for the given epoch.
     * 2. If it's a new epoch, updates the epoch information and calculates additional rewards:
     *    - Adds staking and operation rewards to be sent to the staking contract.
     *    - Calculates public pool rewards.
     * 3. Sets the epoch info (epoch number, start and end timestamps).
     * 4. Calculates staking rewards for the provided node addresses.
     *
     * Note: This function has side effects, including updating epoch information.
     */
    function _prepareRewardsData(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards
    ) internal returns (RewardsData memory data) {
        // check operation rewards
        _checkRewards(epoch, nodeAddrs, operationRewards);

        // update epoch info if it's the next epoch
        if (epoch == _currentEpoch + 1) {
            _updateEpochInfo(epoch);

            // amount of rewards sent to staking contract at the start of each epoch
            data.rewardsToSend += _totalStakingRewardsPerEpoch + _totalOperationRewardsPerEpoch;

            // public pool rewards will be settled only at the start of each epoch
            data.publicPoolRewards = _getPublicPoolStakingRewards();
        }

        data.epochInfo = [epoch, _startTimestamp, _endTimestamp];
        data.stakingRewards = _getStakingRewards(nodeAddrs);
    }

    /// @dev Returns staking rewards per epoch for public pool
    function _getPublicPoolStakingRewards() internal view returns (uint256) {
        (, uint256 totalStaking,) = IStaking(_staking).getPoolInfo();
        if (totalStaking == 0) return 0;

        uint256 publicPoolTokens = IStaking(_staking).getPublicPool().stakingPoolTokens;
        return (publicPoolTokens * _totalStakingRewardsPerEpoch) / totalStaking;
    }

    /**
     * @dev Calculates the staking rewards for a list of node addresses.
     * @param nodeAddrs An array of node addresses to calculate rewards for.
     * @return nodeRewards An array of calculated staking rewards corresponding to each node
     * address.
     * The reward for each node is calculated as:
     * (node's staking tokens * total staking rewards per epoch) / total staking
     *
     * Note: This function has a side effect of potentially updating the total staking snapshot
     * for the current epoch through the _getTotalStaking() call. As we need a snapshot of
     * totalStaking to calculate the staking rewards of each node at the start of each epoch.
     */
    function _getStakingRewards(address[] calldata nodeAddrs)
        internal
        returns (uint256[] memory nodeRewards)
    {
        uint256 len = nodeAddrs.length;
        nodeRewards = new uint256[](len);

        // get total staking of all nodes
        uint256 totalStaking = _getTotalStaking();
        if (totalStaking == 0) return nodeRewards;

        for (uint256 i = 0; i < len; i++) {
            uint256 nodeStakings = IStaking(_staking).getNode(nodeAddrs[i]).stakingPoolTokens;
            nodeRewards[i] = (nodeStakings * _totalStakingRewardsPerEpoch) / totalStaking;
        }
    }

    /// @dev returns amount of total staking tokens
    function _getTotalStaking() internal returns (uint256 totalStaking) {
        totalStaking = _totalStakingSnapshot[_currentEpoch];
        if (totalStaking == 0) {
            (, totalStaking,) = IStaking(_staking).getPoolInfo();

            _totalStakingSnapshot[_currentEpoch] = totalStaking;
        }
    }

    function _isRewarded(uint256 epoch, address nodeAddr) internal view returns (bool) {
        return _rewardedAddresses[epoch][nodeAddr];
    }
}
