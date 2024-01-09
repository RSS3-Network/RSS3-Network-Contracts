// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Utils} from "./Utils.sol";
import {Staking} from "../../src/Staking.sol";
import {Chips} from "../../src/Chips.sol";
import {Settlement} from "../../src/Settlement.sol";
import {RSS3Token} from "../../src/mocks/RSS3Token.sol";
import {TransparentUpgradeableProxy} from "../../src/upgradeability/TransparentUpgradeableProxy.sol";
import {InternalStaking} from "./InternalStaking.sol";
import {InternalSettlement} from "./InternalSettlement.sol";

contract CommonTest is Utils {
    address public constant alice = address(0x111);
    address public constant bob = address(0x222);
    address public constant carol = address(0x333);
    address public constant dave = address(0x444);
    address public constant eve = address(0x555);
    address public constant frank = address(0x666);

    address public constant proxyAdmin = address(0x777);
    address public constant pauseAccount = address(0x888);
    address public constant oracleAccount = address(0x999);

    uint256 public constant stakeUnbondingPeriod = 22.5 days;
    uint256 public constant depositUnbondingPeriod = 22.5 days;

    uint256 internal _initialAmount = 100000000 ether;

    uint256 public constant nodeSlashFraction = 200;
    uint256 public constant userSlashFraction = 100;
    uint256 public constant stakeRatio = 25;
    uint256 public constant minDeposit = 10000 ether;
    address public constant treasury = address(0xaaa);

    string public constant chipsName = "RSS3 Chips";
    string public constant chipsSymbol = "Chips";

    uint64 internal constant _defaultTaxFraction = uint64(1000);

    RSS3Token internal _rss3;
    Staking internal _staking;
    Chips internal _chips;
    Settlement internal _settlement;
    InternalStaking internal _internalStakingTest;
    InternalSettlement internal _internalSettlementTest;

    function _setUp() internal {
        // deploy rss3 token
        _rss3 = new RSS3Token(address(this));
        // deploy chips token
        _chips = new Chips();
        // deploy account oracle
        _settlement = new Settlement();

        _internalStakingTest = new InternalStaking(
            address(_rss3),
            treasury,
            stakeRatio,
            stakeUnbondingPeriod,
            depositUnbondingPeriod,
            nodeSlashFraction,
            userSlashFraction,
            minDeposit
        );
        _internalStakingTest.initialize(address(_chips), pauseAccount, oracleAccount);

        // deploy and init Staking contract
        Staking stakingImpl = new Staking(
            address(_rss3),
            treasury,
            stakeRatio,
            stakeUnbondingPeriod,
            depositUnbondingPeriod,
            nodeSlashFraction,
            userSlashFraction,
            minDeposit
        );

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(stakingImpl),
            proxyAdmin,
            abi.encodeWithSignature(
                // solhint-disable-next-line max-line-length
                "initialize(address,address,address)",
                address(_chips),
                pauseAccount,
                oracleAccount
            )
        );
        _staking = Staking(address(proxy));

        // init chips token
        _chips.initialize(chipsName, chipsSymbol, address(_staking));

        // init account oracle
        uint256 totalRewards = (3 * _rss3.totalSupply()) / 100;
        _rss3.approve(address(_settlement), totalRewards);

        _settlement.initialize(address(_staking), oracleAccount, block.timestamp, 20, 1);

        vm.startPrank(oracleAccount);
        _staking.grantRole(_staking.ORACLE_ROLE(), address(_settlement));
        vm.stopPrank();

        _internalSettlementTest = new InternalSettlement();
        _rss3.approve(address(_internalSettlementTest), totalRewards);

        _internalSettlementTest.initialize(address(_staking), oracleAccount, 0, 0, 1);

        // label test accounts
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(carol, "carol");
        vm.label(dave, "dave");
        vm.label(eve, "eve");
        vm.label(frank, "frank");
        vm.label(address(_staking), "staking");
        vm.label(address(_settlement), "settlement");
        vm.label(address(_chips), "chips");
    }

    function _createNode(address to) internal {
        vm.prank(to);
        _staking.createNode(to, "Name", "Description", _defaultTaxFraction, false);
    }

    function _createPublicGoodNode(address to) internal {
        vm.prank(to);
        _staking.createNode(to, "Name", "Description", _defaultTaxFraction, true);
    }
}
