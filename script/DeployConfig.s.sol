// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,no-console
pragma solidity 0.8.20;

import {console2 as console} from "forge-std/console2.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

/// @title DeployConfig
/// @notice Represents the configuration required to deploy the system. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract DeployConfig is Script {
    string internal _json;

    address public proxyAdminOwner;
    address public pauseAccount;
    address public oracleAccount;
    uint256 public depositUnbondingPeriod;
    uint256 public stakeUnbondingPeriod;
    address public treasury;
    string public chipsName;
    string public chipsSymbol;
    uint256 public settlementStartTime;
    uint256 public operationRewardsPercent;
    address public paymentProcessor;
    address public networkParamsManager;
    bool public isAlphaPhase;

    constructor(string memory _path) {
        console.log("DeployConfig: reading file %s", _path);
        try vm.readFile(_path) returns (string memory data) {
            _json = data;
        } catch {
            console.log("Warning: unable to read config. Do not deploy unless you are not using config.");
            return;
        }

        proxyAdminOwner = stdJson.readAddress(_json, "$.proxyAdminOwner");
        pauseAccount = stdJson.readAddress(_json, "$.pauseAccount");
        oracleAccount = stdJson.readAddress(_json, "$.oracleAccount");
        depositUnbondingPeriod = stdJson.readUint(_json, "$.depositUnbondingPeriod");
        stakeUnbondingPeriod = stdJson.readUint(_json, "$.stakeUnbondingPeriod");
        treasury = stdJson.readAddress(_json, "$.treasury");
        chipsName = stdJson.readString(_json, "$.chipsName");
        chipsSymbol = stdJson.readString(_json, "$.chipsSymbol");
        settlementStartTime = stdJson.readUint(_json, "$.settlementStartTime");
        operationRewardsPercent = stdJson.readUint(_json, "$.operationRewardsPercent");
        paymentProcessor = stdJson.readAddress(_json, "$.paymentProcessor");
        networkParamsManager = stdJson.readAddress(_json, "$.networkParamsManager");
        isAlphaPhase = stdJson.readBool(_json, "$.isAlphaPhase");
    }
}
