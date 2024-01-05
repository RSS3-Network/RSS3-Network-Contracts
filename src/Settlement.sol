// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ISettlement} from "./interfaces/ISettlement.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Settlement is ISettlement, IErrors, Initializable, AccessControlEnumerable {
    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Staking token contract.
    IERC20 internal _token;

    /// @dev Duration of an epoch.
    uint256 internal constant _epochDuration = 22.5 days;

    /// @dev Total rewards of the first year.
    uint256 internal _totalRewards;
    uint256 internal _totalStakingRewardsPerEpoch;
    uint256 internal _totalRequestBonusPerEpoch;

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
        uint256 requsetBonusPercent,
        uint256 startEpoch // set as param for upgradeability
    ) external override initializer {
        _staking = staking;
        _token = IERC20(IStaking(staking).stakingToken());

        _epoch = startEpoch;

        _grantRole(ORACLE_ROLE, oracleAccount);

        _totalRewards = (3 * _token.totalSupply()) / 100;

        _updateRewardsRatio(requsetBonusPercent);

        // deposit the total incentive tokens of the next year in the settlement contract
        // for the next year's rewards, the settlement contract will mint tokens from token's contracts
        _token.transferFrom(msg.sender, address(this), _totalRewards);

        _startTimestamp = startTime;
    }

    function updateRewardsRatio(uint256 requestBonusPercent) external override onlyRole(ORACLE_ROLE) {
        _updateRewardsRatio(requestBonusPercent);
    }

    /// @inheritdoc ISettlement
    function distributeRewards(
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestCounts
    ) external override onlyRole(ORACLE_ROLE) {
        if (nodeAddrs.length != requestFees.length || nodeAddrs.length != requestCounts.length)
            revert InvalidArrayLength();

        uint256[] memory requestBonuses = _getRequestBonuses(_totalRequestBonusPerEpoch, requestCounts);

        (uint256 publicPoolReward, uint256[] memory stakingRewards) = _getStakingRewards(nodeAddrs);

        uint256 endTimestamp = block.timestamp;

        IStaking(_staking).distributeRewards(
            _epoch,
            _startTimestamp,
            endTimestamp,
            nodeAddrs,
            requestFees,
            requestBonuses,
            stakingRewards,
            publicPoolReward
        );

        _startTimestamp = endTimestamp;
        _epoch++;

        IERC20(_token).transfer(_staking, _totalStakingRewardsPerEpoch + _totalRequestBonusPerEpoch);
    }

    /// @inheritdoc ISettlement
    function setTaxFraction4PublicPool(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        uint256 length = nodeAddrs.length;

        if (length == 0) revert EmptyNodeList();

        uint256 totalTaxFraction;
        for (uint256 i = 0; i < length; i++) {
            DataTypes.Node memory node = IStaking(_staking).getNode(nodeAddrs[i]);
            totalTaxFraction += node.taxFraction;
        }
        IStaking(_staking).setTaxFraction4PublicPool(uint64(totalTaxFraction / length));
    }

    /// @inheritdoc ISettlement
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).slashNodes(nodeAddrs);
    }

    /// @inheritdoc ISettlement
    function stakingContract() external view override returns (address) {
        return _staking;
    }

    function getBonusInfo() external view override returns (uint256, uint256) {
        return (_totalRequestBonusPerEpoch, _totalStakingRewardsPerEpoch);
    }

    function _updateRewardsRatio(uint256 requestBonusPercent) internal {
        uint256 rewardsPerEpoch = _totalRewards / (365 days / _epochDuration);

        _totalRequestBonusPerEpoch = (rewardsPerEpoch * requestBonusPercent) / 100;
        _totalStakingRewardsPerEpoch = (rewardsPerEpoch * (100 - requestBonusPercent)) / 100;
    }

    /// @dev returns staking rewards
    function _getStakingRewards(address[] calldata nodeAddrs) internal view returns (uint256, uint256[] memory) {
        uint256 sum = 0;

        DataTypes.Node[] memory nodes = new DataTypes.Node[](nodeAddrs.length + 1);

        DataTypes.Node memory publicPool = IStaking(_staking).getPublicPool();

        sum = publicPool.rewardPool;

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            nodes[i] = IStaking(_staking).getNode(nodeAddrs[i]);

            sum += nodes[i].rewardPool;
        }

        if (sum == 0) return (0, new uint256[](nodeAddrs.length));

        uint256 publicPoolReward = (publicPool.rewardPool * _totalStakingRewardsPerEpoch) / sum;

        uint256[] memory nodesReward = new uint256[](nodeAddrs.length);

        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            nodesReward[i] = (nodes[i].rewardPool * _totalStakingRewardsPerEpoch) / sum;
        }

        return (publicPoolReward, nodesReward);
    }

    /// @dev returns request bonuses
    function _getRequestBonuses(
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

        for (uint256 i = 0; i < requestCounts.length; i++) {
            result[i] = (_log2(requestCounts[i] / sum + 1) * totalBonus * 693147) / 1000000; // ln 2 = 693147 / 1000000
        }

        return result;
    }

    /// @dev returns log2(x)
    // solhint-disable-next-line code-complexity
    function _log2(uint256 x) internal pure returns (uint256 n) {
        if (x >= 2 ** 128) {
            x >>= 128;
            n += 128;
        }
        if (x >= 2 ** 64) {
            x >>= 64;
            n += 64;
        }
        if (x >= 2 ** 32) {
            x >>= 32;
            n += 32;
        }
        if (x >= 2 ** 16) {
            x >>= 16;
            n += 16;
        }
        if (x >= 2 ** 8) {
            x >>= 8;
            n += 8;
        }
        if (x >= 2 ** 4) {
            x >>= 4;
            n += 4;
        }
        if (x >= 2 ** 2) {
            x >>= 2;
            n += 2;
        }
        if (x >= 2 ** 1) {
            n += 1;
        }
    }
}
