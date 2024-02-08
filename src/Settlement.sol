// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISettlement} from "./interfaces/ISettlement.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Settlement is ISettlement, IErrors, Initializable, AccessControlEnumerable {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /// @dev Duration of an epoch.
    uint256 public constant EPOCH_DURATION = 18 hours;

    /// @dev Total rewards of the first year.
    uint256 public constant TOTAL_REWARDS_PER_YEAR = 30000000 * 10 ** 18;

    /// @dev Staking contract address.
    address internal _staking;

    uint256 internal _totalStakingRewardsPerEpoch;
    uint256 internal _totalOperationRewardsPerEpoch;

    /// @dev The current epoch.
    uint256 internal _currentEpoch;

    // keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    uint256 internal _startTimestamp;
    uint256 internal _endTimestamp;

    // total staking for each epoch
    mapping(uint256 epoch => uint256 totalStaking) internal _totalStakings;
    // distributed staking rewards for each epoch
    mapping(uint256 epoch => uint256 stakingRewards) internal _distributedStakingRewards;
    // distributed operation rewards for each epoch
    mapping(uint256 epoch => uint256 operationRewards) internal _distributedOperationRewards;

    /// @inheritdoc ISettlement
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 operationRewardsPercent,
        uint256 startEpoch // set as param for upgradeability
    ) external override initializer {
        _staking = staking;
        _currentEpoch = startEpoch;
        _startTimestamp = startTime;

        _updateRewardsRatio(operationRewardsPercent);

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
        uint256[] calldata operationRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != requestFees.length || nodeAddrs.length != operationRewards.length) {
            revert InvalidArrayLength();
        }

        // check epoch number
        if (epoch < _currentEpoch) {
            revert InvalidEpochNumber();
        }

        uint256 publicPoolRewards;
        uint256 amountToTransfer;
        if (epoch == _currentEpoch + 1) {
            // check submission interval
            uint256 submissionInterval = EPOCH_DURATION - 1 hours;
            if (block.timestamp - _startTimestamp <= submissionInterval) revert SubmissionIntervalNotElapsed();

            // update current epoch
            _currentEpoch = epoch;
            // update epoch timestamp
            _startTimestamp = _endTimestamp;
            _endTimestamp = block.timestamp;

            // send operationRewards and stakingRewards to staking contract
            amountToTransfer = _totalStakingRewardsPerEpoch + _totalOperationRewardsPerEpoch;

            // public pool rewards will be settled only at the start of each epoch
            publicPoolRewards = _getPublicPoolStakingRewards();

            // save totalStaking for current epoch
            (, _totalStakings[_currentEpoch], ) = IStaking(_staking).getPoolInfo();
        }

        uint256[] memory stakingRewards = _getStakingRewards(nodeAddrs);

        _checkRewards(nodeAddrs, operationRewards, stakingRewards);

        IStaking(_staking).distributeRewards{value: amountToTransfer}(
            [epoch, _startTimestamp, _endTimestamp],
            nodeAddrs,
            requestFees,
            operationRewards,
            stakingRewards,
            publicPoolRewards
        );
    }

    /// @dev check distributed operationRewards and stakingRewards not exceeds the max rewards per epoch
    function _checkRewards(
        address[] memory nodeAddrs,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards
    ) internal {
        uint256 distributedOperationRewards = _distributedOperationRewards[_currentEpoch];
        uint256 distributedStakingRewards = _distributedStakingRewards[_currentEpoch];
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            distributedOperationRewards += operationRewards[i];
            distributedStakingRewards += stakingRewards[i];
        }

        if (distributedOperationRewards > _totalOperationRewardsPerEpoch) revert OperationRewardsExceed();
        if (distributedStakingRewards > _totalStakingRewardsPerEpoch) revert StakingRewardsExceed();

        _distributedOperationRewards[_currentEpoch] = distributedOperationRewards;
        _distributedStakingRewards[_currentEpoch] = distributedStakingRewards;
    }

    /// @dev Returns staking rewards per epoch for public pool
    function _getPublicPoolStakingRewards() internal view returns (uint256) {
        (, uint256 totalStaking, ) = IStaking(_staking).getPoolInfo();
        if (totalStaking == 0) return 0;

        uint256 publicPoolTokens = IStaking(_staking).getPublicPool().stakingPoolTokens;
        return (publicPoolTokens * _totalStakingRewardsPerEpoch) / totalStaking;
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
            (, totalStaking, ) = IStaking(_staking).getPoolInfo();
        }
    }
}
