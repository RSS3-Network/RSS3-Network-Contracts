// SPDX-License-Identifier: MIT
// solhint-disable no-console,ordering
pragma solidity 0.8.20;

import {Deployer} from "./Deployer.sol";
import {DeployConfig} from "./DeployConfig.s.sol";
import {Staking} from "../src/Staking.sol";
import {Chips} from "../src/Chips.sol";
import {AccountOracle} from "../src/AccountOracle.sol";
import {console2 as console} from "forge-std/console2.sol";
import {TransparentUpgradeableProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";

contract Deploy is Deployer {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PAUSE_ROLE =
        0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d; // keccak256("PAUSE_ROLE");
    bytes32 public constant ORACLE_ROLE =
        0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1; // keccak256("ORACLE_ROLE");

    // solhint-disable private-vars-leading-underscore
    DeployConfig internal cfg;

    /// @notice Modifier that wraps a function in broadcasting.
    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    /// @notice The name of the script, used to ensure the right deploy artifacts
    ///         are used.
    function name() public pure override returns (string memory name_) {
        name_ = "Deploy";
    }

    function setUp() public override {
        super.setUp();
        string memory path = string.concat(
            vm.projectRoot(),
            "/deploy-config/",
            deploymentContext,
            ".json"
        );
        cfg = new DeployConfig(path);

        console.log("Deploying from %s", deployScript);
        console.log("Deployment context: %s", deploymentContext);
    }

    /* solhint-disable comprehensive-interface */
    function run() external {
        deployImplementations();

        deployProxies();

        initialize();
    }

    /// @notice Initialize all of the proxies
    function initialize() public {
        initializeStaking();
        initializeChips();
        initializeAccountOracle();
    }

    /// @notice Deploy all of the proxies
    function deployProxies() public {
        deployProxy("Staking");
        deployProxy("Chips");
        deployProxy("AccountOracle");
    }

    /// @notice Deploy all of the logic contracts
    function deployImplementations() public {
        deployStaking();
        deployChips();
        deployAccountOracle();
    }

    function deployProxy(string memory _name) public broadcast returns (address addr_) {
        address logic = mustGetAddress(_stripSemver(_name));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy({
            _logic: logic,
            initialOwner: cfg.proxyAdminOwner(),
            _data: ""
        });

        // check states
        address proxyAdmin = address(uint160(uint256(vm.load(address(proxy), OWNER_KEY))));
        address admin = address(uint160(uint256(vm.load(proxyAdmin, bytes32(0)))));
        require(admin == cfg.proxyAdminOwner(), "proxy admin assert error");

        string memory proxyName = string.concat(_name, "Proxy");
        save(proxyName, address(proxy));
        console.log("%s deployed at %s", proxyName, address(proxy));

        addr_ = address(proxy);
    }

    function deployStaking() public broadcast returns (address addr_) {
        Staking staking = new Staking();

        // check states
        require(!staking.hasRole(PAUSE_ROLE, cfg.pauseAccount()), "pause role error");

        save("Staking", address(staking));
        console.log("Staking deployed at %s", address(staking));
        addr_ = address(staking);
    }

    function deployChips() public broadcast returns (address addr_) {
        Chips chips = new Chips();

        // check states
        require(chips.stakingContract() == address(0), "check chips contract error");

        save("Chips", address(chips));
        console.log("Chips deployed at %s", address(chips));
        addr_ = address(chips);
    }

    function deployAccountOracle() public broadcast returns (address addr_) {
        AccountOracle accountOracle = new AccountOracle();

        // check states
        require(!accountOracle.hasRole(ORACLE_ROLE, cfg.oracleAccount()), "oracle role error");
        require(
            accountOracle.stakingContract() == address(0),
            "check accountOracle contract error"
        );

        save("AccountOracle", address(accountOracle));
        console.log("AccountOracle deployed at %s", address(accountOracle));
        addr_ = address(accountOracle);
    }

    function initializeStaking() public broadcast {
        Staking stakingProxy = Staking(mustGetAddress("StakingProxy"));
        address chipsProxy = mustGetAddress("ChipsProxy");
        address accountOracleProxy = mustGetAddress("AccountOracleProxy");

        stakingProxy.initialize(
            cfg.pauseAccount(),
            accountOracleProxy,
            chipsProxy,
            cfg.rss3Token(),
            cfg.stakeUnbondingPeriod(),
            cfg.depositUnbondingPeriod()
        );

        // check states
        require(stakingProxy.hasRole(PAUSE_ROLE, cfg.pauseAccount()), "check pause role error");
        require(stakingProxy.hasRole(PAUSE_ROLE, accountOracleProxy), "check oracle role error");
        require(stakingProxy.stakingToken() == cfg.rss3Token(), "check staking token error");
        require(stakingProxy.chipsContract() == chipsProxy, "check chips token error");
    }

    function initializeChips() public broadcast {
        Chips chipsProxy = Chips(mustGetAddress("ChipsProxy"));
        address stakingProxy = mustGetAddress("StakingProxy");

        chipsProxy.initialize(stakingProxy);

        // check states
        require(chipsProxy.stakingContract() == stakingProxy, "check chip contract error");
    }

    function initializeAccountOracle() public broadcast {
        AccountOracle accountOracleProxy = AccountOracle(mustGetAddress("AccountOracleProxy"));
        address stakingProxy = mustGetAddress("StakingProxy");

        accountOracleProxy.initialize(stakingProxy, cfg.oracleAccount());

        // check states
        require(
            accountOracleProxy.hasRole(ORACLE_ROLE, cfg.oracleAccount()),
            "check oracle role error"
        );
        require(
            accountOracleProxy.stakingContract() == stakingProxy,
            "check accountOracle contract error"
        );
    }
}
