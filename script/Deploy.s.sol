// SPDX-License-Identifier: MIT
// solhint-disable no-console,ordering,custom-errors
pragma solidity 0.8.20;

import {Deployer} from "./Deployer.sol";
import {DeployConfig} from "./DeployConfig.s.sol";
import {Staking} from "../src/Staking.sol";
import {Chips} from "../src/Chips.sol";
import {Settlement} from "../src/Settlement.sol";
import {NetworkParams} from "../src/NetworkParams.sol";
import {console2 as console} from "forge-std/console2.sol";
import {TransparentUpgradeableProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";

contract Deploy is Deployer {
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    // keccak256("PAUSE_ROLE");
    bytes32 public constant PAUSE_ROLE = 0x139c2898040ef16910dc9f44dc697df79363da767d8bc92f2e310312b816e46d;
    // keccak256("ORACLE_ROLE");
    bytes32 public constant ORACLE_ROLE = 0x68e79a7bf1e0bc45d0a330c573bc367f9cf464fd326078812f301165fbda4ef1;
    // keccak256("ADMIN_ROLE")
    bytes32 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

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
        string memory path = string.concat(vm.projectRoot(), "/deploy-config/", deploymentContext, ".json");
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
        initializeSettlement();
        initializeNetworkParams();
    }

    /// @notice Deploy all of the proxies
    function deployProxies() public {
        deployProxy("Staking");
        deployProxy("Chips");
        deployProxy("Settlement");
        deployProxy("NetworkParams");
    }

    /// @notice Deploy all of the logic contracts
    function deployImplementations() public {
        deployStaking();
        deployChips();
        deploySettlement();
        deployNetworkParams();
    }

    function deployProxy(string memory _name) public broadcast returns (address addr_) {
        address logic = mustGetAddress(_stripSemver(_name));
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy({
            _logic: logic,
            admin_: cfg.proxyAdminOwner(),
            _data: ""
        });

        // check states
        address proxyAdmin = address(uint160(uint256(vm.load(address(proxy), OWNER_KEY))));
        require(proxyAdmin == cfg.proxyAdminOwner(), "proxy admin assert error");

        string memory proxyName = string.concat(_name, "Proxy");
        save(proxyName, address(proxy));
        console.log("%s deployed at %s", proxyName, address(proxy));

        addr_ = address(proxy);
    }

    function deployStaking() public broadcast returns (address addr_) {
        Staking staking = new Staking(
            cfg.treasury(),
            cfg.stakeRatio(),
            cfg.stakeUnbondingPeriod(),
            cfg.depositUnbondingPeriod(),
            cfg.nodeSlashRateBasisPoints(),
            cfg.userSlashRateBasisPoints(),
            cfg.depositBaseline(),
            cfg.taxRateBasisPointsBaseline(),
            cfg.paymentProcessor()
        );

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

    function deploySettlement() public broadcast returns (address addr_) {
        Settlement settlement = new Settlement(cfg.checkEpochInterval());

        // check states
        require(!settlement.hasRole(ORACLE_ROLE, cfg.oracleAccount()), "oracle role error");
        require(settlement.stakingContract() == address(0), "check settlement contract error");
        require(
            settlement.CHECK_EPOCH_INTERVAL() == cfg.checkEpochInterval(),
            "check settlement checkEpochInterval error"
        );

        save("Settlement", address(settlement));
        console.log("Settlement deployed at %s", address(settlement));
        addr_ = address(settlement);
    }

    function deployNetworkParams() public broadcast returns (address addr_) {
        NetworkParams params = new NetworkParams();

        save("NetworkParams", address(params));
        console.log("NetworkParams deployed at %s", address(params));
        addr_ = address(params);
    }

    function initializeStaking() public broadcast {
        Staking stakingProxy = Staking(mustGetAddress("StakingProxy"));
        address chipsProxy = mustGetAddress("ChipsProxy");
        address settlementProxy = mustGetAddress("SettlementProxy");

        stakingProxy.initialize(chipsProxy, cfg.pauseAccount(), settlementProxy, cfg.isAlphaPhase());
        // check states
        require(stakingProxy.hasRole(PAUSE_ROLE, cfg.pauseAccount()), "check pause role error");
        require(stakingProxy.hasRole(ORACLE_ROLE, settlementProxy), "check oracle role error");
        require(stakingProxy.chipsContract() == chipsProxy, "check chips token error");
        require(stakingProxy.isAlphaPhase() == cfg.isAlphaPhase(), "check alpha phase error");
    }

    function initializeChips() public broadcast {
        Chips chipsProxy = Chips(mustGetAddress("ChipsProxy"));
        address stakingProxy = mustGetAddress("StakingProxy");

        chipsProxy.initialize(cfg.chipsName(), cfg.chipsSymbol(), stakingProxy);

        // check states
        require(chipsProxy.stakingContract() == stakingProxy, "check chip contract error");
    }

    function initializeSettlement() public broadcast {
        Settlement settlementProxy = Settlement(mustGetAddress("SettlementProxy"));
        address stakingProxy = mustGetAddress("StakingProxy");

        settlementProxy.initialize(
            stakingProxy,
            cfg.oracleAccount(),
            cfg.settlementStartTime(),
            cfg.operationRewardsPercent()
        );

        // check states
        require(settlementProxy.hasRole(ORACLE_ROLE, cfg.oracleAccount()), "check oracle role error");
        require(settlementProxy.stakingContract() == stakingProxy, "check settlement contract error");
        require(settlementProxy.currentEpoch() == 0, "check start epoch error");
        require(settlementProxy.EPOCH_DURATION() == 18 hours, "check start epoch error");
        require(settlementProxy.TOTAL_REWARDS_PER_YEAR() == 30000000 ether, "check start epoch error");
    }

    function initializeNetworkParams() public broadcast {
        NetworkParams networkParamsProxy = NetworkParams(mustGetAddress("NetworkParamsProxy"));

        networkParamsProxy.initialize(cfg.networkParamsManager());

        // check states
        require(networkParamsProxy.hasRole(ADMIN_ROLE, cfg.networkParamsManager()), "check admin role error");
    }
}
