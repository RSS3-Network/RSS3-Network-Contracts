// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Utils} from "./Utils.sol";
import {Staking} from "../../src/Staking.sol";
import {Chips} from "../../src/Chips.sol";
import {Settlement} from "../../src/Settlement.sol";
import {RSS3Token} from "../../src/mocks/RSS3Token.sol";
import {TransparentUpgradeableProxy} from "../../src/upgradeability/TransparentUpgradeableProxy.sol";

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
    uint256 public constant delegateUnbondingPeriod = 22.5 days;

    uint256 internal _initialAmount = 100000000 ether;

    uint256 public constant nodeSlashFraction = 200;
    uint256 public constant userSlashFraction = 100;
    uint256 public constant stakeRatio = 25;
    uint256 public constant stakeBaseline = 10000 ether;
    uint256 public constant depositBaseline = 10000 ether;
    address public constant treasury = address(0xaaa);

    string public constant chipsName = "RSS3 Chips";
    string public constant chipsSymbol = "Chips";

    RSS3Token internal _rss3;
    Staking internal _staking;
    Chips internal _chips;
    Settlement internal _settlement;

    function _setUp() internal {
        // deploy rss3 token
        _rss3 = new RSS3Token(address(this));
        // deploy chips token
        _chips = new Chips();
        // deploy account oracle
        _settlement = new Settlement();

        // deploy and init Staking contract
        Staking stakingImpl = new Staking();

        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(stakingImpl),
            proxyAdmin,
            abi.encodeWithSignature(
                // solhint-disable-next-line max-line-length
                "initialize(address,address,addressw,address,uint256,uint256,uint256,uint256,uint256,uint256,uint256,address)",
                pauseAccount,
                address(_settlement),
                address(_chips),
                address(_rss3),
                stakeUnbondingPeriod,
                delegateUnbondingPeriod,
                nodeSlashFraction,
                userSlashFraction,
                stakeRatio,
                stakeBaseline,
                depositBaseline,
                treasury
            )
        );
        _staking = Staking(address(proxy));

        // init chips token
        _chips.initialize(chipsName, chipsSymbol, address(_staking));
        // init account oracle
        _settlement.initialize(address(_staking), oracleAccount);
    }
}
