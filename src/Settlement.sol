// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISettlement} from "./interfaces/ISettlement.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract Settlement is ISettlement, IErrors, Initializable, AccessControlEnumerable {
    using Math for uint256;
    using SafeCast for uint256;

    /// @dev Duration of an epoch.
    uint256 public constant EPOCH_DURATION = 18 hours;

    /// @dev Total rewards of the first year.
    uint256 public constant TOTAL_REWARDS_PER_YEAR = 30000000 * 10 ** 18;

    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    /// @dev Staking contract address.
    address internal _staking;

    uint256 internal _totalStakingRewardsPerEpoch;
    uint256 internal _totalOperationRewardsPerEpoch;

    /// @dev The current epoch.
    uint256 internal _currentEpoch;

    uint256 internal _startTimestamp;
    uint256 internal _endTimestamp;

    // total staking for each epoch
    mapping(uint256 epoch => uint256 totalStaking) internal _totalStakings;
    // distributed operation rewards for each epoch
    mapping(uint256 epoch => uint256 operationRewards) internal _distributedOperationRewards;
    // rewarded node addresses
    mapping(uint256 epoch => mapping(address nodeAddr => bool rewarded)) internal _rewardedAddresses;

    /// @inheritdoc ISettlement
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 operationRewardsPercent
    ) external override initializer {
        _staking = staking;
        _startTimestamp = startTime;

        _updateRewardsRatio(operationRewardsPercent);

        // grants `ORACLE_ROLE`
        _grantRole(ORACLE_ROLE, oracleAccount);
    }

    /// @inheritdoc ISettlement
    function updateRewardsRatio(uint256 operationRewardsPercent) external override onlyRole(ORACLE_ROLE) {
        _updateRewardsRatio(operationRewardsPercent);
    }

    /// @inheritdoc ISettlement
    function distributeRewards(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata operationRewards,
        bool isFinal
    ) external payable override onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != requestFees.length || nodeAddrs.length != operationRewards.length) {
            revert InvalidArrayLength();
        }

        // check epoch number
        // epoch number must be the current epoch or the next epoch
        if (epoch < _currentEpoch || epoch > _currentEpoch + 1) {
            revert InvalidEpochNumber(_currentEpoch, epoch);
        }

        // check requestFees
        uint256 amountToSend;
        for (uint256 i = 0; i < requestFees.length; i++) {
            amountToSend += requestFees[i];
        }
        if (amountToSend > msg.value) revert InsufficientRequestFees();

        // start of a new epoch
        uint256 publicPoolRewards;
        if (epoch == _currentEpoch + 1) {
            _checkSubmissionInterval();

            _updateEpochInfo(epoch);

            // send operationRewards and stakingRewards to staking contract
            amountToSend += _totalStakingRewardsPerEpoch + _totalOperationRewardsPerEpoch;

            // public pool rewards will be settled only at the start of each epoch
            publicPoolRewards = _getPublicPoolStakingRewards();

            // save totalStaking for current epoch
            (, _totalStakings[_currentEpoch]) = IStaking(_staking).getPoolInfo();
        }

        // settlement phase
        IStaking(_staking).setSettlementPhase(!isFinal);

        _checkRewards(epoch, nodeAddrs, operationRewards);

        uint256[3] memory epochInfo = [epoch, _startTimestamp, _endTimestamp];
        uint256[] memory stakingRewards = _getStakingRewards(nodeAddrs);
        IStaking(_staking).distributeRewards{value: amountToSend}(
            epochInfo,
            nodeAddrs,
            requestFees,
            operationRewards,
            stakingRewards,
            publicPoolRewards
        );
    }

    /// @inheritdoc ISettlement
    function setTaxRateBasisPoints4PublicPool(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        uint256 length = nodeAddrs.length;

        if (length == 0) revert EmptyNodeList();

        uint256 totalTaxRateBasisPoints;
        for (uint256 i = 0; i < length; i++) {
            DataTypes.Node memory node = IStaking(_staking).getNode(nodeAddrs[i]);
            totalTaxRateBasisPoints += node.taxRateBasisPoints;
        }
        IStaking(_staking).setTaxRateBasisPoints4PublicPool((totalTaxRateBasisPoints / length).toUint64());
    }

    /// @inheritdoc ISettlement
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).slashNodes(nodeAddrs);
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
        // rewardsPerEpoch = TOTAL_REWARDS_PER_YEAR / (365 days / EPOCH_DURATION)
        // operationRewardsPerEpoch = rewardsPerEpoch * (operationRewardsPercent / 100)%
        // stakingBonusPerEpoch = rewardsPerEpoch *  (1 - (operationRewardsPercent / 100))%

        _totalOperationRewardsPerEpoch =
            (TOTAL_REWARDS_PER_YEAR * EPOCH_DURATION * operationRewardsPercent) /
            (100 * 365 days);
        _totalStakingRewardsPerEpoch =
            ((TOTAL_REWARDS_PER_YEAR * EPOCH_DURATION) * (100 - operationRewardsPercent)) /
            (100 * 365 days);
    }

    /// @dev check distributed operationRewards and stakingRewards not exceeds the max rewards per epoch
    function _checkRewards(uint256 epoch, address[] memory nodeAddrs, uint256[] memory operationRewards) internal {
        uint256 distributedOperationRewards = _distributedOperationRewards[epoch];
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            if (_isRewarded(epoch, nodeAddrs[i])) revert RewardsAlreadyDistributed(nodeAddrs[i]);
            _rewardedAddresses[epoch][nodeAddrs[i]] = true;

            distributedOperationRewards += operationRewards[i];
        }

        if (distributedOperationRewards > _totalOperationRewardsPerEpoch) revert OperationRewardsExceed();

        _distributedOperationRewards[epoch] = distributedOperationRewards;
    }

    function _updateEpochInfo(uint256 epoch) internal {
        // update current epoch
        _currentEpoch = epoch;
        // update epoch timestamp
        if (_endTimestamp > 0) {
            _startTimestamp = _endTimestamp;
        }
        _endTimestamp = block.timestamp;
    }

    /// @dev check submission interval
    function _checkSubmissionInterval() internal view {
        uint256 submissionInterval = EPOCH_DURATION - 1 hours;
        if (block.timestamp - _startTimestamp <= submissionInterval) revert SubmissionIntervalNotElapsed();
    }

    /// @dev Returns staking rewards per epoch for public pool
    function _getPublicPoolStakingRewards() internal view returns (uint256) {
        (, uint256 totalStaking) = IStaking(_staking).getPoolInfo();
        if (totalStaking == 0) return 0;

        uint256 publicPoolTokens = IStaking(_staking).getPublicPool().stakingPoolTokens;
        return (publicPoolTokens * _totalStakingRewardsPerEpoch) / totalStaking;
    }

    /// @dev returns staking rewards
    function _getStakingRewards(address[] calldata nodeAddrs) internal view returns (uint256[] memory nodeRewards) {
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
    function _getTotalStaking() internal view returns (uint256 totalStaking) {
        totalStaking = _totalStakings[_currentEpoch];
        if (totalStaking == 0) {
            (, totalStaking) = IStaking(_staking).getPoolInfo();
        }
    }

    function _isRewarded(uint256 epoch, address nodeAddr) internal view returns (bool) {
        return _rewardedAddresses[epoch][nodeAddr];
    }
}
