// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Utils} from "./Utils.sol";
import {DataTypes} from "../../src/libraries/DataTypes.sol";
import {Staking} from "../../src/Staking.sol";
import {Chips} from "../../src/Chips.sol";
import {Settlement} from "../../src/Settlement.sol";
import {RSS3Token} from "../../src/mocks/RSS3Token.sol";
import {TransparentUpgradeableProxy as Proxy} from "../../src/upgradeability/TransparentUpgradeableProxy.sol";
import {InternalStaking} from "./InternalStaking.sol";
import {InternalSettlement} from "./InternalSettlement.sol";

contract CommonTest is Utils {
    address public constant alice = address(0x111);
    address public constant bob = address(0x222);
    address public constant carol = address(0x333);
    address public constant dave = address(0x444);
    address public constant eve = address(0x555);

    address public constant proxyAdmin = address(0x777);
    address public constant pauseAccount = address(0x888);
    address public constant oracleAccount = address(0x999);

    bytes32 public constant PAUSE_ROLE = 0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;

    address[] public zeroAddrArr = new address[](0);
    uint256[] public zeroUintArr = new uint256[](0);

    uint256 public constant stakeUnbondingPeriod = 22.5 days;
    uint256 public constant depositUnbondingPeriod = 22.5 days;

    uint256 internal _initialAmount = 100000000 ether;

    uint256 public constant nodeSlashRateBasisPoints = 100;
    uint256 public constant userSlashRateBasisPoints = 50;
    uint256 public constant stakeRatio = 25;
    uint256 public constant minDeposit = 10000 ether;
    uint256 public constant minTaxRateBasisPoints = 500;
    uint256 public constant slashReporterBonusRateBasisPoints = 200;
    address public constant treasury = address(0xaaa);

    string public constant chipsName = "Open Chips";
    string public constant chipsSymbol = "Chips";

    uint64 internal constant _defaultTaxRateBasisPoints = uint64(1000);

    RSS3Token internal _rss3;
    Staking internal _staking;
    Chips internal _chips;
    Settlement internal _settlement;
    InternalStaking internal _internalStakingTest;
    InternalSettlement internal _internalSettlementTest;

    // SVGGenerator internal _svgGenerator;

    function _setUp() internal {
        // deploy rss3 token
        _rss3 = new RSS3Token(address(this));

        // deploy Staking contract
        Staking stakingImpl = new Staking(
            treasury,
            stakeRatio,
            stakeUnbondingPeriod,
            depositUnbondingPeriod,
            nodeSlashRateBasisPoints,
            userSlashRateBasisPoints,
            minDeposit,
            minTaxRateBasisPoints,
            slashReporterBonusRateBasisPoints
        );
        // deploy chips token
        Chips chipsImpl = new Chips();
        // deploy settlement contract
        Settlement settlementImpl = new Settlement();

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
        _staking.initialize(address(_chips), pauseAccount, address(_settlement));
        _settlement.initialize(address(_staking), oracleAccount, block.timestamp, 20);
        _chips.initialize(chipsName, chipsSymbol, address(_staking));

        _internalStakingTest = new InternalStaking(
            treasury,
            stakeRatio,
            stakeUnbondingPeriod,
            depositUnbondingPeriod,
            nodeSlashRateBasisPoints,
            userSlashRateBasisPoints,
            minDeposit,
            minTaxRateBasisPoints,
            slashReporterBonusRateBasisPoints
        );
        _internalStakingTest.initialize(address(_chips), address(_settlement), oracleAccount);

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

    function _disableAlphaPhase() internal {
        vm.prank(pauseAccount);
        _staking.disableAlphaPhase();
    }

    function _createPublicGoodNode(address to) internal {
        vm.prank(to);
        _staking.createNode("Name", "Description", 0, true);
    }

    function _checkDistribution(
        uint256[] memory depositAmounts,
        uint256[] memory stakeAmounts,
        address[] memory nodeAddrs,
        uint256[] memory taxAmounts,
        uint256[] memory operationRewards,
        uint256[] memory stakingRewards
    ) internal {
        // status check
        for (uint256 i = 0; i < nodeAddrs.length; i++) {
            DataTypes.Node memory node = _staking.getNode(nodeAddrs[i]);
            uint256 newOperationPool = depositAmounts[i] + taxAmounts[i];
            assertEq(node.operationPoolTokens, newOperationPool, "check operation pool failed");

            uint256 newStakingPool = stakeAmounts[i] + operationRewards[i] + stakingRewards[i] - taxAmounts[i];
            assertEq(node.stakingPoolTokens, newStakingPool, "check staking pool failed");
        }
    }

    function _deposit(address account, uint256 depositAmount) internal {
        vm.deal(account, depositAmount);

        vm.prank(account);
        _staking.deposit{value: depositAmount}();
    }

    function _getTreasuryAmount() internal returns (uint256) {
        address treasury_ = _staking.TREASURY();

        uint256 balanceBefore = address(treasury_).balance;
        _staking.withdraw2Treasury();
        uint256 balanceAfter = address(treasury_).balance;

        return balanceAfter - balanceBefore;
    }

    function _denominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _getFullTax(uint256 rewards, uint64 taxRateBasisPoints) internal pure returns (uint256) {
        return (rewards * taxRateBasisPoints) / _denominator();
    }
}
