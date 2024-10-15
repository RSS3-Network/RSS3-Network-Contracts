// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console,max-line-length,quotes,code-complexity
pragma solidity 0.8.24;

import {LibZip} from "@solady/utils/LibZip.sol";

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";

contract CompressParams is Script {
    // solhint-disable-next-line function-max-lines
    function run() public view {
        string memory params = _readInput("network_parameter");
        bytes memory result = LibZip.flzCompress(bytes(params));
        console.logBytes(result);
    }

    // read network config params from json file
    function _readInput(string memory input) private view returns (string memory) {
        string memory inputDir = string.concat(vm.projectRoot(), "/script/input/2331/");
        string memory file = string.concat(input, ".json");
        return vm.readFile(string.concat(inputDir, file));
    }
}
