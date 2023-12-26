// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IAccountOracle} from "./interfaces/IAccountOracle.sol";
import {IStaking} from "./interfaces/IStaking.sol";
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
        address[] calldata nodeAddrs,
        uint256[] calldata operatorPoolRewards,
        uint256[] calldata rewardPoolRewards
    ) external override onlyRole(ORACLE_ROLE) {
        IStaking(_staking).distributeRewards(
            epoch,
            startTimestamp,
            endTimestamp,
            nodeAddrs,
            operatorPoolRewards,
            rewardPoolRewards
        );
    }
}
