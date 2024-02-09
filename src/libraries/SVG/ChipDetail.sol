// SPDX-License-Identifier: MIT
// solhint-disable code-complexity
pragma solidity 0.8.20;

import {ChipDetail1to2} from "./ChipDetail1to2.sol";
import {ChipDetail3to4} from "./ChipDetail3to4.sol";
import {ChipDetail5} from "./ChipDetail5.sol";
import {ChipDetail6} from "./ChipDetail6.sol";
import {ChipDetail7} from "./ChipDetail7.sol";
import {ChipDetail8to9} from "./ChipDetail8to9.sol";
import {ChipDetail10to11} from "./ChipDetail10to11.sol";

library ChipDetail {
    function getChipDetail(uint256 id) external pure returns (string memory) {
        uint256 idx = id % 11;
        if (idx < 2) {
            return ChipDetail1to2.getChipDetail(idx);
        }
        if (idx < 4) {
            return ChipDetail3to4.getChipDetail(idx);
        }
        if (idx == 4) {
            return ChipDetail5.getChipDetail(idx);
        }
        if (idx == 5) {
            return ChipDetail6.getChipDetail(idx);
        }
        if (idx == 6) {
            return ChipDetail7.getChipDetail(idx);
        }
        if (idx < 9) {
            return ChipDetail8to9.getChipDetail(idx);
        } else {
            // Covers idx == 9 or idx == 10
            return ChipDetail10to11.getChipDetail(idx);
        }
    }
}
