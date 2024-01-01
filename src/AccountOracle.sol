// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IAccountOracle} from "./interfaces/IAccountOracle.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

contract AccountOracle is IAccountOracle, IErrors, Initializable, AccessControlEnumerable {
    /// @dev Staking contract address.
    address internal _staking;

    // keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    /// @inheritdoc IAccountOracle
    function initialize(address staking_, address oracleAccount) external override initializer {
        _staking = staking_;

        _grantRole(ORACLE_ROLE, oracleAccount);
    }

    /// @inheritdoc IAccountOracle
    function distributeRewards(
        uint256 epoch,
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 totalRequestBonus,
        address[] calldata nodeAddrs,
        uint256[] calldata requestFees,
        uint256[] calldata requestCounts,
        uint256[] calldata stakingRewards
    ) external override onlyRole(ORACLE_ROLE) {
        if (
            nodeAddrs.length != requestFees.length ||
            nodeAddrs.length != requestCounts.length ||
            nodeAddrs.length != stakingRewards.length
        ) revert InvalidArrayLength();

        uint256[] memory requestBonuses = _getRequestBonuses(totalRequestBonus, requestCounts);

        IStaking(_staking).distributeRewards(
            epoch,
            startTimestamp,
            endTimestamp,
            nodeAddrs,
            requestFees, // request fees will be sent to operator pool
            requestBonuses,
            stakingRewards
        );

        // TODO: transfer tokens to staking contract
        // maybe the reward and slashing can be completed in one call,
        // and the slashing is done before the reward.
    }

    /// @inheritdoc IAccountOracle
    function setTaxFraction4PublicPool(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        uint256 length = nodeAddrs.length;

        uint128 totalTaxFraction;
        for (uint256 i = 0; i < length; i++) {
            DataTypes.Node memory node = IStaking(_staking).getNode(nodeAddrs[i]);
            totalTaxFraction += node.taxFraction;
        }
        IStaking(_staking).setTaxFraction4PublicPool(uint64(totalTaxFraction / length));
    }

    /// @inheritdoc IAccountOracle
    function slashNodes(address[] calldata nodeAddrs) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).slashNodes(nodeAddrs);
    }

    /// @inheritdoc IAccountOracle
    function stakingContract() external view override returns (address) {
        return _staking;
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
            uint256 logValue = _log2(requestCounts[i]);

            sum += logValue;
            result[i] = logValue;
        }

        uint256 bonusPerUnit = totalBonus / sum;
        for (uint256 i = 0; i < requestCounts.length; i++) {
            result[i] *= bonusPerUnit;
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
