// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {Utils} from "test/helpers/Utils.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {Chips} from "../src/Chips.sol";
import {AccountOracle} from "../src/AccountOracle.sol";
import {RSS3Token} from "../src/mocks/RSS3Token.sol";
import {Events} from "../src/libraries/Events.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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

    uint256 internal _initialAmount = 100000000 ether;

    RSS3Token internal _rss3;
    Staking internal _staking;
    Chips internal _chips;
    AccountOracle internal _accountOracle;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // deploy rss3 token
        _rss3 = new RSS3Token(address(this));
        // deploy chips token
        _chips = new Chips();
        // deploy account oracle
        _accountOracle = new AccountOracle();

        // deploy and init Staking contract
        Staking stakingImpl = new Staking();
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(stakingImpl),
            proxyAdmin,
            abi.encodeWithSignature(
                "initialize(address,address,address,address,uint256,uint256)",
                pauseAccount,
                address(_accountOracle),
                address(_chips),
                address(_rss3),
                stakeUnbondingPeriod,
                delegateUnbondingPeriod
            )
        );
        _staking = Staking(address(proxy));

        // init chips token
        _chips.initialize(address(_staking));
        // init account oracle
        _accountOracle.initialize(address(_staking), oracleAccount);

        // transfer tokens
        _rss3.transfer(alice, _initialAmount);
        _rss3.transfer(bob, _initialAmount);
    }

    function testCreateNode(uint64 taxFraction, bool publicGood) public {
        vm.assume(taxFraction <= 10000);

        string memory name = "Alice";
        string memory description = "Alice's node";
        string memory endpoint = "https://alice.com";

        expectEmit();
        emit Events.NodeCreated(alice, name, description, taxFraction, publicGood, endpoint);
        vm.prank(alice);
        _staking.createNode(name, description, taxFraction, publicGood, endpoint);

        DataTypes.Node memory node = _staking.getNode(alice);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.taxFraction, taxFraction);
        assertEq(node.publicGood, publicGood);
        assertEq(node.endpoint, endpoint);
    }

    function testStake(uint256 amount) public {
        vm.assume(amount > 10000 ether && amount < _initialAmount);

        _createNode(alice, uint64(100));

        vm.startPrank(alice);
        _rss3.approve(address(_staking), amount);

        expectEmit();
        emit Transfer(alice, address(_staking), amount);
        expectEmit();
        emit Events.Deposited(alice, amount);
        _staking.deposit(amount);
        vm.stopPrank();
    }

    function testDelegate(uint256 amount) public {
        vm.assume(amount > 500 ether && amount <= 1000000 ether);

        uint256 chipsCount = amount / _staking.SHARES_PER_CHIP();
        uint256 expectedDelegatedAmount = chipsCount * _staking.SHARES_PER_CHIP();

        _createNode(alice, uint64(100));

        // stake
        vm.startPrank(alice);
        _rss3.approve(address(_staking), 10000 ether);
        _staking.deposit(10000 ether);
        vm.stopPrank();

        // delegate
        vm.startPrank(bob);
        _rss3.approve(address(_staking), amount);

        for (uint256 i = 1; i <= chipsCount; i++) {
            expectEmit();
            emit TestEvents.Transfer(address(0), bob, i);
        }
        expectEmit();
        emit Transfer(bob, address(_staking), expectedDelegatedAmount);
        expectEmit();
        emit Events.Delegated(bob, alice, expectedDelegatedAmount, 1, chipsCount);
        _staking.delegate(alice, amount);
        vm.stopPrank();
    }

    function _createNode(address nodeAddr, uint64 taxFraction) internal {
        vm.prank(nodeAddr);
        _staking.createNode("name", "description", taxFraction, false, "http://endpoint");
    }
}
