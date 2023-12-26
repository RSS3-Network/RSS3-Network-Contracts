// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Utils} from "test/helpers/Utils.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {Chips} from "../src/Chips.sol";
import {RSS3Token} from "../src/mocks/RSS3Token.sol";
import {Events} from "../src/libraries/Events.sol";
import {TransparentUpgradeableProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";

contract StakingTest is Utils {
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
    uint256 public constant delegateUnbondingPeriod = 30 days;

    RSS3Token internal _rss3;
    Staking internal _staking;
    Chips internal _chips;

    function setUp() public {
        // deploy rss3 token
        _rss3 = new RSS3Token(address(this));
        // deploy chips token
        _chips = new Chips();

        // deploy and init Staking contract
        Staking stakingImpl = new Staking();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(stakingImpl),
            proxyAdmin,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,uint256,uint256)",
                pauseAccount,
                oracleAccount,
                address(_chips),
                address(_rss3),
                stakeUnbondingPeriod,
                delegateUnbondingPeriod
            )
        );
        _staking = Staking(address(proxy));

        // init chips token
        _chips.initialize(address(_staking));
    }

    function testCreateNode(uint256 taxFraction) public {
        vm.assume(taxFraction <= 10000);

        string memory name = "Alice";
        string memory description = "Alice's node";
        string memory endpoint = "https://alice.com";

        expectEmit();
        emit Events.NodeCreated(alice, name, description, taxFraction, endpoint);
        vm.prank(alice);
        _staking.createNode(name, description, taxFraction, endpoint);

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.taxFraction, taxFraction);
        assertEq(node.endpoint, endpoint);
    }
}
