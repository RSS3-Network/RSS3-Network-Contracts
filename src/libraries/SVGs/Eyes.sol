// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;
import {Eyes1to9} from "./Eyes1to9.sol";
import {Eyes10to18} from "./Eyes10to18.sol";

library Eyes {
    function getEyes(uint256 id) external pure returns (string memory, string memory) {
        uint256 idx = id % 18;
        if (idx < 9) {
            return Eyes1to9.getEyes(idx);
        } else {
            return Eyes10to18.getEyes(idx);
        }
    }
}
