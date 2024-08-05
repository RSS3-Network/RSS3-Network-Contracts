// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ISettlement} from "./interfaces/ISettlement.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {
    InvalidArrayLength,
    InvalidEpochNumber,
    SubmissionIntervalNotElapsed,
    RewardsAlreadyDistributed,
    OperationRewardsExceed
} from "./libraries/Errors.sol";

contract Settlement is ISettlement, Initializable, AccessControlEnumerable {
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
    mapping(uint256 epoch => uint256 totalStaking) internal _totalStakingSnapshot;
    // distributed operation rewards for each epoch
    mapping(uint256 epoch => uint256 operationRewards) internal _distributedOperationRewards;
    // rewarded node addresses
    mapping(uint256 epoch => mapping(address nodeAddr => bool rewarded)) internal _rewardedAddresses;

    // solhint-disable-next-line comprehensive-interface
    receive() external payable {}

    /// @inheritdoc ISettlement
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 operationRewardsPercent
    )
        external
        override
        // warn: check the initializer version and if it should be initialized when deploying
        // current initializer version is:
        // mainnet: 1
        // testnet: 2
        reinitializer(3)
    {
        if (staking != address(0)) {
            _staking = staking;
        }

        if (startTime > 0) {
            _startTimestamp = startTime;
        }

        _updateRewardsRatio(operationRewardsPercent);

        // grants `ORACLE_ROLE`
        if (oracleAccount != address(0)) {
            _grantRole(ORACLE_ROLE, oracleAccount);
        }
    }

    /// @inheritdoc ISettlement
    function distributeRewards(
        uint256 epoch,
        address[] calldata nodeAddrs,
        uint256[] calldata operationRewards,
        uint256[] calldata requestCounts,
        bool isFinal
    ) external override onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != operationRewards.length || nodeAddrs.length != requestCounts.length) {
            revert InvalidArrayLength();
        }

        // check epoch number
        _checkEpoch(epoch);
        // check operation rewards
        _checkRewards(epoch, nodeAddrs, operationRewards);

        /// @dev we use a temp struct here to avoid `stack too deep`
        DataTypes.RewardsData memory data;
        if (epoch == _currentEpoch + 1) {
            _updateEpochInfo(epoch);

            // amount of rewards sent to staking contract at the start of each epoch
            data.rewardsToSend += _totalStakingRewardsPerEpoch + _totalOperationRewardsPerEpoch;

            // public pool rewards will be settled only at the start of each epoch
            data.publicPoolRewards = _getPublicPoolStakingRewards();

            // save totalStaking snapshot
            _saveTotalStakingSnapshot();
        }

        // settlement phase
        IStaking(_staking).setSettlementPhase(!isFinal);

        data.epochInfo = [epoch, _startTimestamp, _endTimestamp];
        data.stakingRewards = _getStakingRewards(nodeAddrs);
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
    function setTaxRateBasisPoints4PublicPool(uint64 taxRateBasisPoints) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).setTaxRateBasisPoints4PublicPool(taxRateBasisPoints);
    }

    /// @inheritdoc ISettlement
    function recordSlashing(
        DataTypes.Slashing[] calldata slashings,
        address[] calldata reporters,
        string[] calldata reasons
    ) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).recordSlashing(slashings, reporters, reasons);
    }

    /// @inheritdoc ISettlement
    function revokeSlashing(DataTypes.Slashing[] calldata epochIds) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).revokeSlashing(epochIds);
    }

    /// @inheritdoc ISettlement
    function commitSlashing(DataTypes.Slashing[] calldata epochIds) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).commitSlashing(epochIds);
    }

    /// @inheritdoc ISettlement
    function setNodeStatus(
        address[] calldata nodeAddrs,
        DataTypes.NodeStatus[] calldata status
    ) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).setNodeStatus(nodeAddrs, status);
    }

    /// @inheritdoc ISettlement
    function demoteNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).demoteNodes(_currentEpoch, nodeAddrs);
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

    function _saveTotalStakingSnapshot() internal {
        (, _totalStakingSnapshot[_currentEpoch], ) = IStaking(_staking).getPoolInfo();
    }

    function _updateEpochInfo(uint256 epoch) internal {
        // update current epoch
        _currentEpoch = epoch;

        // update epoch timestamp
        if (_endTimestamp > 0) {
            _startTimestamp = _endTimestamp;
        }
        _endTimestamp = block.timestamp;

        // check epoch interval
        uint256 submissionInterval = EPOCH_DURATION - 1 hours;
        if (_endTimestamp - _startTimestamp <= submissionInterval) revert SubmissionIntervalNotElapsed();
    }

    /// @dev check epoch number
    function _checkEpoch(uint256 epoch) internal view {
        // epoch number must be the current epoch or the next epoch
        uint256 curEpoch = _currentEpoch;
        if (epoch < curEpoch || epoch > curEpoch + 1) {
            revert InvalidEpochNumber(curEpoch, epoch);
        }
    }

    /// @dev Returns staking rewards per epoch for public pool
    function _getPublicPoolStakingRewards() internal view returns (uint256) {
        (, uint256 totalStaking, ) = IStaking(_staking).getPoolInfo();
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
        totalStaking = _totalStakingSnapshot[_currentEpoch];
        if (totalStaking == 0) {
            (, totalStaking, ) = IStaking(_staking).getPoolInfo();
        }
    }

    function _isRewarded(uint256 epoch, address nodeAddr) internal view returns (bool) {
        return _rewardedAddresses[epoch][nodeAddr];
    }
}
