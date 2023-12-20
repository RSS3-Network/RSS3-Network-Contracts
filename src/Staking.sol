// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {IStaking} from "./interfaces/IStaking.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Staking is IStaking, Pausable, Initializable, AccessControlEnumerable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _nodes;

    /// ACL
    bytes32 public constant PAUSE_ROLE =
        0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d; // keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE =
        0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1; // keccak256("ORACLE_ROLE");

    /// @inheritdoc IStaking
    function initialize(address pauseAccount, address oracleAccount) external override initializer {
        _setupRole(PAUSE_ROLE, pauseAccount);
        _setupRole(ORACLE_ROLE, oracleAccount);
    }

    /// @inheritdoc IStaking
    function pause() external override whenNotPaused onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @inheritdoc IStaking
    function unpause() external override whenPaused onlyRole(PAUSE_ROLE) {
        _unpause();
    }

    /// @inheritdoc IStaking
    function createNode(string calldata name, address rewardAddress) external override {}

    /// @inheritdoc IStaking
    function deleteNode(address addr) external override {}

    /// @inheritdoc IStaking
    function setNodeOperatorRewardAddress(
        address nodeAddr,
        address rewardAddress
    ) external override {}

    /// @inheritdoc IStaking
    function stake(uint256 amount) external override {}

    /// @inheritdoc IStaking
    function requestUnstake(uint256 amount) external override {}

    /// @inheritdoc IStaking
    function claimUnstake(uint256[] calldata requestIds) external override whenNotPaused {}

    /// @inheritdoc IStaking
    function delegate(
        address nodeAddr,
        uint256 amount
    ) external override returns (uint256, uint256) {
        return (0, 0);
    }

    /// @inheritdoc IStaking
    function requestUndelegate(
        uint256 chipsId,
        uint256 amount
    ) external override returns (uint256) {
        return 0;
    }

    /// @inheritdoc IStaking
    function claimUndelegate(uint256[] calldata requestIds) external override whenNotPaused {}

    /// @inheritdoc IStaking
    function distributeRewards() external override onlyRole(ORACLE_ROLE) {}

    /// @inheritdoc IStaking
    function getNodes() external view returns (DataTypes.Node[] memory) {
        DataTypes.Node[] memory res = new DataTypes.Node[](1);
        return res;
    }
}
