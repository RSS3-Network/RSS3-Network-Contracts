// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IAccountOracle} from "./interfaces/IAccountOracle.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {Errors} from "./libraries/Errors.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    AccessControlEnumerable
} from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

contract AccountOracle is IAccountOracle, Initializable, AccessControlEnumerable {
    /// @dev Staking contract address.
    address internal _staking;

    bytes32 public constant ORACLE_ROLE =
        0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1; // keccak256("ORACLE_ROLE");

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
        ) revert Errors.InvalidArrayLength();

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
    function _log2(uint256 x) internal pure returns (uint256 result) {
        if (x == 0) return 0;

        while ((x & 1) == 0) {
            x >>= 1;
            result += 1;
        }
    }
}
