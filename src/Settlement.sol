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
    uint256 internal _epoch;

    // keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    uint256 internal _startTimestamp;

    /// @inheritdoc ISettlement
    function initialize(
        address staking,
        address oracleAccount,
        uint256 startTime,
        uint256 operationRewardsPercent,
        uint256 startEpoch // set as param for upgradeability
    ) external override initializer {
        _staking = staking;
        _epoch = startEpoch;
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
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestCounts
    ) external override onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != requestFees.length || nodeAddrs.length != requestCounts.length)
            revert InvalidArrayLength();

        uint256[] memory operationRewards = _getOperationRewards(_totalOperationRewardsPerEpoch, requestCounts);

        (uint256 publicPoolReward, uint256[] memory stakingRewards) = _getStakingRewards(nodeAddrs);

        uint256 endTimestamp = block.timestamp;

        IStaking(_staking).distributeRewards{value: _totalStakingRewardsPerEpoch + _totalOperationRewardsPerEpoch}(
            [_epoch, _startTimestamp, endTimestamp],
            nodeAddrs,
            requestFees,
            operationRewards,
            stakingRewards,
            publicPoolReward
        );

        _startTimestamp = endTimestamp;
        _epoch++;
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
        return _epoch;
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
        uint256 totalRewards = _totalStakingRewardsPerEpoch;

        // get total staking of all nodes
        (, uint256 totalStaking, ) = IStaking(_staking).getPoolInfo();
        if (totalStaking == 0) return (0, new uint256[](len));

        uint256[] memory nodeStakings = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            nodeStakings[i] = IStaking(_staking).getNode(nodeAddrs[i]).stakingPoolTokens;
        }

        // get staking rewards for public pool and all nodes
        DataTypes.Node memory publicPool = IStaking(_staking).getPublicPool();
        publicPoolReward = (publicPool.stakingPoolTokens * totalRewards) / totalStaking;

        nodesReward = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            nodesReward[i] = (nodeStakings[i] * totalRewards) / totalStaking;
        }
    }

    /// @dev returns request bonuses
    function _getOperationRewards(
        uint256 totalBonus,
        uint256[] memory requestCounts
    ) internal pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](requestCounts.length);

        /// @dev sum of log2 of each element in `requestCounts`
        uint256 sum;
        for (uint256 i = 0; i < requestCounts.length; i++) {
            sum += requestCounts[i];
        }

        if (sum == 0) return result;

        // get weights for bonus
        uint256[] memory weights = new uint256[](requestCounts.length);
        uint256 sumWeight;
        for (uint256 i = 0; i < requestCounts.length; i++) {
            weights[i] = _getWeight(requestCounts[i], sum);
            sumWeight += weights[i];
        }

        // get bonus for each node
        for (uint256 i = 0; i < requestCounts.length; i++) {
            result[i] = (totalBonus * weights[i]) / sumWeight;
        }

        return result;
    }

    /// @dev log2(requestCount/totalCount +1) * G , where G = ln(2)
    function _getWeight(uint256 requestCount, uint256 totalCount) internal pure returns (uint256) {
        // scale with scalar to keep more precision
        uint256 scalar = type(uint64).max;
        uint256 scaledA = (requestCount + totalCount) * scalar;
        uint256 res = _log2(scaledA / totalCount) - 630000; // log2(scalar) = 630000
        return (res * 693147) / 1000000; // ln 2 = 693147 / 1000000
    }

    /// @dev log2(x) with precision 4
    function _log2(uint256 x) internal pure returns (uint256) {
        uint256 n = x.log2();
        x = x >> n;

        uint256 frac = 0;
        uint256 base = 1;
        for (uint256 i = 0; i < 32; i++) {
            base *= 2;
            x *= x;
            if (x >= base) {
                frac += 10000 >> (i + 1);
                x >>= 1;
            }
        }

        return n * 10000 + frac;
    }
}
