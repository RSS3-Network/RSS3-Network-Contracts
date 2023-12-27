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

    function _getRequestBonuses(
        uint256 totalBonus,
        uint256[] memory requestCounts
    ) internal pure returns (uint256[] memory) {
        uint256[] memory res = new uint256[](requestCounts.length);

        uint256 sum;
        for (uint256 i = 0; i < requestCounts.length; i++) {
            res[i] = _log2(requestCounts[i]);
            sum += res[i];
        }

        for (uint256 i = 0; i < requestCounts.length; i++) {
            res[i] = (totalBonus * res[i]) / sum;
        }

        return res;
    }

    function _log2(uint256 x) internal pure returns (uint256 result) {
        while (x > 1) {
            x >>= 1;
            result += 1;
        }
    }
}
