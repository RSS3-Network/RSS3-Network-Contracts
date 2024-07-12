// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/Script.sol";
import {NetworkParams} from "../src/NetworkParams.sol";

contract SetParams is Script {
    /* solhint-disable comprehensive-interface */
    function run() public {
        address contractAddress = vm.envAddress("NETWORK_PARAMS_ADDRESS");
        require(contractAddress != address(0), "Invalid contract address");
        NetworkParams networkParams = NetworkParams(contractAddress);

        string memory params = _readInput("network_parameter");

        // invoke the setParams function
        vm.startBroadcast();
        networkParams.setParams(100, params);
        vm.stopBroadcast();
    }

    // read network config params from json file
    function _readInput(string memory input) private view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/");
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(input, ".json");
        return vm.readFile(string.concat(inputDir, chainDir, file));
    }
}
