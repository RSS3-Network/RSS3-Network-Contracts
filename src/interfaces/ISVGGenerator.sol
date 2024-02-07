// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {DataTypes} from "../libraries/DataTypes.sol";

interface ISVGGenerator {
    function generateSVG(
        DataTypes.NodeTraits memory nodeTraits,
        DataTypes.ChipTraits memory chipTraits
    ) external view returns (string memory);

    /**
     * @dev Get the count of traits for each category
     * @return colorCount, frameCount, chipCornerCount, chipDetailCount
     */
    function getNodeTraitsCount() external view returns (uint8, uint8, uint8, uint8);

    /**
     * @dev Get the count of traits for each category
     * @return eyeCount, mouthCount, headShapeCount, headDetailCount
     */
    function getChipTraitsCount() external view returns (uint8, uint8, uint8, uint8);
}
