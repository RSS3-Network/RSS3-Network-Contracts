// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.24;

import {DeployConfig} from "../../script/DeployConfig.s.sol";
import {Chips} from "../../src/Chips.sol";

import {Settlement} from "../../src/Settlement.sol";
import {Staking} from "../../src/Staking.sol";
import {Const} from "../../src/libraries/Const.sol";
import {Demotion, Node, NodeStatus} from "../../src/libraries/DataTypes.sol";
import {StorageLib} from "../../src/libraries/StorageLib.sol";
import {RSS3Token} from "../../src/mocks/RSS3Token.sol";
import {InternalSettlement} from "./InternalSettlement.sol";
import {Utils} from "./Utils.sol";
import {
    TransparentUpgradeableProxy as Proxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract CommonTest is Utils {
    address public constant alice = address(0x111);
    address public constant bob = address(0x222);
    address public constant carol = address(0x333);
    address public constant dave = address(0x444);
    address public constant eve = address(0x555);

    address public constant proxyAdmin = address(0x777);
    address public constant pauseAccount = address(0x888);
    address public constant oracleAccount = address(0x999);

    bytes32 public constant PAUSE_ROLE =
        0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;
    bytes32 public constant ORACLE_ROLE =
        0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    address[] public zeroAddrArr = new address[](0);
    uint256[] public zeroUintArr = new uint256[](0);

    uint256 public constant stakeUnbondingPeriod = 0;
    uint256 public constant depositUnbondingPeriod = 0;

    uint256 internal _initialAmount = 100_000_000 ether;

    string public constant chipsName = "Open Chips";
    string public constant chipsSymbol = "Chips";

    string public constant REASON1 = "demotion reason1";
    string public constant REASON2 = "demotion reason2";
    address public constant REPORTER = address(0xeeeeee);

    uint64 internal constant _defaultTaxRateBasisPoints = uint64(1000);

    DeployConfig internal _cfg;

    RSS3Token internal _rss3;
    Staking internal _staking;
    Chips internal _chips;
    Settlement internal _settlement;
    InternalSettlement internal _internalSettlementTest;

    // events
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Paused(address account);
    event Unpaused(address account);

    // errors
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error EnforcedPause();
    error ExpectedPause();

    function _setUp() internal {
        // read config from local.json
        string memory path = string.concat(vm.projectRoot(), "/deploy-config/", "local" ".json");
        _cfg = new DeployConfig(path);

        // deploy rss3 token
        _rss3 = new RSS3Token(address(this));

        // deploy Staking contract
        Staking stakingImpl = new Staking(
            _cfg.treasury(),
            _cfg.stakeUnbondingPeriod(),
            _cfg.depositUnbondingPeriod(),
            _cfg.paymentProcessor()
        );

        // deploy chips token
        Chips chipsImpl = new Chips();
        // deploy settlement contract
        Settlement settlementImpl = new Settlement(_cfg.checkEpochInterval());

        // deploy staking proxy
        Proxy stakingProxy = new Proxy(address(stakingImpl), proxyAdmin, "");
        _staking = Staking(payable(stakingProxy));

        // deploy chips proxy
        Proxy chipsProxy = new Proxy(address(chipsImpl), proxyAdmin, "");
        _chips = Chips(payable(chipsProxy));

        // deploy settlement proxy
        Proxy settlementProxy = new Proxy(address(settlementImpl), proxyAdmin, "");
        _settlement = Settlement(payable(settlementProxy));

        // init
        _staking.initialize(
            address(_chips), pauseAccount, address(_settlement), _cfg.isAlphaPhase(), false
        );
        _settlement.initialize(address(_staking), oracleAccount, block.timestamp, 20);
        _chips.initialize(chipsName, chipsSymbol, address(_staking));

        _internalSettlementTest = new InternalSettlement();
        _internalSettlementTest.initialize(address(_staking), oracleAccount, 0, 0);

        // label test accounts
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(carol, "carol");
        vm.label(dave, "dave");
        vm.label(eve, "eve");
        vm.label(address(_staking), "staking");
        vm.label(address(_settlement), "settlement");
        vm.label(address(_chips), "chips");
    }

    function _createNode(address to) internal {
        vm.prank(to);
        _staking.createNode("Name", "Description", _defaultTaxRateBasisPoints, false);
    }

    function _createPublicGoodNode(address to) internal {
        vm.prank(to);
        _staking.createNode("Name", "Description", 0, true);
    }

    function _deposit(address account, uint256 depositAmount) internal {
        vm.deal(account, depositAmount);

        vm.prank(account);
        _staking.deposit{value: depositAmount}();
    }

    function _presetNodeStatus(address nodeAddr, NodeStatus status) internal {
        bytes32 slot =
            keccak256(abi.encode(nodeAddr, StorageLib.NODES_MAPPING_BY_NODE_ADDRESS_SLOT));
        // node.status is at offset 9 of struct Node
        slot = bytes32(uint256(slot) + 9);
        vm.store(address(_staking), slot, bytes32(uint256(status)));
    }

    function _getTreasuryAmount() internal returns (uint256) {
        address treasury_ = _staking.TREASURY();

        uint256 balanceBefore = address(treasury_).balance;
        _staking.withdraw2Treasury();
        uint256 balanceAfter = address(treasury_).balance;

        return balanceAfter - balanceBefore;
    }

    function _getNodeStatus(address nodeAddr) internal view returns (NodeStatus status) {
        status = _staking.getNode(nodeAddr).status;
    }

    function _checkDistribution(
        uint256[] memory depositAmounts,
        uint256[] memory stakeAmounts,
        address[] memory nodeAddrs,
        uint256[] memory taxAmounts,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards
    ) internal view {
        // status check
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            Node memory node = _staking.getNode(nodeAddrs[i]);
            uint256 newOperationPool = depositAmounts[i] + taxAmounts[i];
            assertApproxEqAbs(
                node.operationPoolTokens, newOperationPool, 4, "check operation pool failed"
            );

            uint256 newStakingPool =
                stakeAmounts[i] + operationRewards[i] + stakingRewards[i] - taxAmounts[i];
            assertApproxEqAbs(
                node.stakingPoolTokens, newStakingPool, 4, "check staking pool failed"
            );
        }
    }

    function _checkNodeProfile(address nodeAddr, string memory name, string memory description)
        internal
        view
    {
        Node memory node = _staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
    }

    function _checkNode(
        address nodeAddr,
        uint256 nodeId,
        string memory name,
        string memory description,
        uint64 taxRateBasisPoints,
        uint256 operationPoolTokens,
        bool publicGood,
        bool alpha
    ) internal view {
        Node memory node = _staking.getNode(nodeAddr);
        _checkNodeProfile(nodeAddr, name, description);
        assertEq(node.nodeId, nodeId);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.publicGood, publicGood);
        assertEq(node.alpha, alpha);
    }

    function _checkDemotion(
        Demotion memory demotion,
        uint256 demotionId,
        address nodeAddr,
        uint256 epoch,
        string memory reason,
        address reporter
    ) internal pure {
        assertEq(demotion.demotionId, demotionId);
        assertEq(demotion.nodeAddr, nodeAddr);
        assertEq(demotion.epoch, epoch);
        assertEq(demotion.reason, reason);
        assertEq(demotion.reporter, reporter);
    }

    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints)
        internal
        pure
        returns (uint256)
    {
        return (rewards * taxRateBasisPoints) / Const.DENOMINATOR;
    }

    function _assertEq(NodeStatus a, NodeStatus b) internal pure {
        assertEq(uint256(a), uint256(b));
    }
}
