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
        if (nodeAddrs.length != requestFees.length || nodeAddrs.length != operationRewards.length)
            revert InvalidArrayLength();

        if (epoch < _currentEpoch) {
            revert InvalidEpochNumber();
        }
        if (epoch == _currentEpoch + 1) {
            // check submission interval
            uint256 submissionInterval = EPOCH_DURATION - 1 hours;
            if (block.timestamp - _startTimestamp <= submissionInterval) revert SubmissionIntervalNotElapsed();

            // update current epoch
            _currentEpoch = epoch;

            _startTimestamp = _endTimestamp;
            _endTimestamp = block.timestamp;
        }

        (uint256 publicPoolReward, uint256[] memory stakingRewards) = _getStakingRewards(nodeAddrs);
        IStaking(_staking).distributeRewards{value: _totalStakingRewardsPerEpoch + _totalOperationRewardsPerEpoch}(
            [epoch, _startTimestamp, _endTimestamp],
            nodeAddrs,
            requestFees,
            operationRewards,
            stakingRewards,
            publicPoolReward
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

    /// @dev returns staking rewards
    function _getStakingRewards(
        address[] calldata nodeAddrs
    ) internal view returns (uint256 publicPoolReward, uint256[] memory nodesReward) {
        uint256 len = nodeAddrs.length;
        nodesReward = new uint256[](len);

        // get total staking of all nodes
        (, uint256 totalStaking, ) = IStaking(_staking).getPoolInfo();
        if (totalStaking == 0) return (0, nodesReward);

        // get staking rewards for public pool and all nodes
        DataTypes.Node memory publicPool = IStaking(_staking).getPublicPool();
        publicPoolReward = (publicPool.stakingPoolTokens * _totalStakingRewardsPerEpoch) / totalStaking;

        for (uint256 i = 0; i < len; i++) {
            uint256 nodeStakings = IStaking(_staking).getNode(nodeAddrs[i]).stakingPoolTokens;
            nodesReward[i] = (nodeStakings * _totalStakingRewardsPerEpoch) / totalStaking;
        }
    }
}
