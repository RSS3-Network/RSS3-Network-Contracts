// SPDX-License-Identifier: MIT
// solhint-disable private-vars-leading-underscore,no-console
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

/// @title DeployConfig
/// @notice Represents the configuration required to deploy the system. It is expected
///         to read the file from JSON. A future improvement would be to have fallback
///         values if they are not defined in the JSON themselves.
contract DeployConfig is Script {
    string internal _json;

    uint256 public chainID;
    address public proxyAdminOwner;
    address public pauseAccount;
    address public oracleAccount;
    address public rss3Token;
    uint256 public depositUnbondingPeriod;
    uint256 public stakeUnbondingPeriod;
    uint256 public nodeSlashFraction;
    uint256 public userSlashFraction;
    uint256 public stakeRatio;

    constructor(string memory _path) {
        console.log("DeployConfig: reading file %s", _path);
        try vm.readFile(_path) returns (string memory data) {
            _json = data;
        } catch {
            console.log("Warning: unable to read config. Do not deploy unless you are not using config.");
            return;
        }

        chainID = stdJson.readUint(_json, "$.chainID");
        proxyAdminOwner = stdJson.readAddress(_json, "$.proxyAdminOwner");
        pauseAccount = stdJson.readAddress(_json, "$.pauseAccount");
        oracleAccount = stdJson.readAddress(_json, "$.oracleAccount");
        rss3Token = stdJson.readAddress(_json, "$.rss3Token");
        depositUnbondingPeriod = stdJson.readUint(_json, "$.stakeUnbondingPeriod");
        stakeUnbondingPeriod = stdJson.readUint(_json, "$.stakeUnbondingPeriod");
        nodeSlashFraction = stdJson.readUint(_json, "$.nodeSlashFraction");
        userSlashFraction = stdJson.readUint(_json, "$.userSlashFraction");
        stakeRatio = stdJson.readUint(_json, "$.stakeRatio");
    }
}
