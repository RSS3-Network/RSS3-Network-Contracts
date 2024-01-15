// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface
pragma solidity 0.8.20;

import {Chips} from "../../src/Chips.sol";

contract InternalChips is Chips {
    function getChipImageSeeds(uint256 tokenId) external view returns (uint256[] memory) {
        return _getRandomTraits(tokenId);
    }

    function getTraitsCount() public view returns (uint256) {
        return _randomTraitCount;
    }
}
