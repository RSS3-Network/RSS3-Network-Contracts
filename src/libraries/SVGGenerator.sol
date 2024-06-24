// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

import {DataTypes} from "./DataTypes.sol";
import {Eyes} from "./SVGs/Eyes.sol";
import {ChipDetail} from "./SVGs/ChipDetail.sol";
import {Head} from "./SVGs/Head.sol";
import {Mouths} from "./SVGs/Mouths.sol";
import {Corners} from "./SVGs/Corners.sol";
import {Frame} from "./SVGs/Frame.sol";

library SVGGenerator {
    string public constant baseSVGHead =
        '<?xml version="1.0" encoding="utf-8"?><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 100 100" style="enable-background:new 0 0 100 100;background-color:black;" xml:space="preserve">';

    string public constant baseSVGTail = "</svg>";

    string public constant color1 = "#DEE5D9";
    string public constant color2 = "#FB1467";
    string public constant color3 = "#1477FB";
    string public constant color4 = "#FFD600";
    string public constant color5 = "#31C040";

    string public constant headShapeSVGs1 =
        '<polygon class="b" points="72,48 72,64 70,64 70,66 68,66 68,68 64,68 64,70 60,70 60,72 40,72 40,70 36,70 36,68 32,68 32,66   30,66 30,64 28,64 28,48 30,48 30,46 32,46 32,44 68,44 68,46 70,46 70,48 "/>';
    string public constant headShapeSVGs2 =
        '<polygon class="b" points="72,44 72,68 70,68 70,70 68,70 68,72 32,72 32,70 30,70 30,68 28,68 28,44 "/>';
    string public constant headShapeSVGs3 =
        '<polygon class="b" points="72,46 72,64 70,64 70,66 68,66 68,68 66,68 66,70 64,70 64,72 36,72 36,70 34,70 34,68 32,68 32,66   30,66 30,64 28,64 28,46 30,46 30,44 70,44 70,46 "/>';

    string public constant headShapeTrait1 = "round";
    string public constant headShapeTrait2 = "square";
    string public constant headShapeTrait3 = "default";

    function getNodeTraitsCount() external pure returns (uint8, uint8, uint8, uint8) {
        return (
            5, // uint8(_colors.length),
            9, //            uint8(_frameSVGs.length),
            7, // uint8(_cornerSVGs.length),
            11 // uint8(_chipDetailSVGs.length)
        );
    }

    function getChipTraitsCount() external pure returns (uint8, uint8, uint8, uint8) {
        return (
            18, // uint8(_eyesSVGs.length),
            19, //uint8(_mouthsSVGs.length),
            3, //uint8(_baseHeadsSVGs.length),
            16 //uint8(_headSVGs.length)
        );
    }

    function generateSVGAndAttributes(
        DataTypes.NodeTraits calldata nodeTraits,
        DataTypes.ChipTraits calldata chipTraits
    ) external pure returns (string memory, string memory) {
        string memory styleSVG = getSVGStyle(
            nodeTraits.frameColor,
            nodeTraits.chipDetailColor,
            chipTraits.headShapeColor,
            chipTraits.headDetailColor
        );

        (string memory innerSVG1, string memory attributes1) = getNodeTraitsInnerSVGAndAttributes(nodeTraits);
        (string memory innerSVG2, string memory attributes2) = getChipTraitsInnerSVGAndAttributes(chipTraits);

        return (
            string.concat(baseSVGHead, styleSVG, innerSVG1, innerSVG2, baseSVGTail),
            string.concat(attributes1, attributes2)
        );
    }

    function getNodeTraitsInnerSVGAndAttributes(
        DataTypes.NodeTraits memory nodeTraits
    ) internal pure returns (string memory, string memory) {
        (string memory corner, string memory cornerTrait) = nodeTraits.pg
            ? (Corners.pgSVG, "Public Good Node")
            : nodeTraits.alpha
                ? (Corners.alphaSVG, "Alpha Node")
                : Corners.getCorner(nodeTraits.chipCornerId);
        (string memory frameSVGs, string memory frameTrait) = Frame.getFrame(nodeTraits.frameId);
        (string memory chipSVGs, string memory chipTrait) = ChipDetail.getChipDetail(nodeTraits.chipDetailId);

        string memory innerSVG1 = string.concat(frameSVGs, '<svg class="c">', chipSVGs, "</svg>", corner);

        string memory attributes1 = string.concat(
            '{"trait_type": "Frame", "value": "',
            frameTrait,
            '"}, {"trait_type": "Chip Detail", "value": "',
            getColor(nodeTraits.frameColor),
            '"}, {"trait_type": "Chip Detail", "value": "',
            chipTrait,
            '"}, {"trait_type": "Chip Detail Color", "value": "',
            getColor(nodeTraits.chipDetailColor),
            '"}, {"trait_type": "Corner", "value": "',
            cornerTrait,
            '"},'
        );

        return (innerSVG1, attributes1);
    }

    function getChipTraitsInnerSVGAndAttributes(
        DataTypes.ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory svgParts, string memory headShapeTrait) = getHeadShape(chipTraits.headShapeId % 3);

        string memory attributes = string.concat(
            '{"trait_type": "Head Shape", "value": "',
            headShapeTrait,
            '"}, {"trait_type": "Head Shape Color", "value": "',
            getColor(chipTraits.headShapeColor),
            '"}'
        );

        (svgParts, attributes) = addEyes(svgParts, attributes, chipTraits);
        (svgParts, attributes) = addMouth(svgParts, attributes, chipTraits);
        (svgParts, attributes) = addHeadDetail(svgParts, attributes, chipTraits);

        return (svgParts, attributes);
    }

    function addEyes(
        string memory svgs,
        string memory attrs,
        DataTypes.ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory eyesSVG, string memory eyesTrait) = Eyes.getEyes(chipTraits.eyesId);

        return (
            string.concat(svgs, eyesSVG),
            string.concat(attrs, ',{"trait_type": "Eyes", "value": "', eyesTrait, '"}')
        );
    }

    function addMouth(
        string memory svgs,
        string memory attrs,
        DataTypes.ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory mouthSVG, string memory mouthTrait) = Mouths.getMouth(chipTraits.mouthId);

        return (
            string.concat(svgs, mouthSVG),
            string.concat(attrs, ',{"trait_type": "Mouth", "value": "', mouthTrait, '"}')
        );
    }

    function addHeadDetail(
        string memory svgs,
        string memory attrs,
        DataTypes.ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory headSVG, string memory headTraits) = Head.getHead(chipTraits.headDetailId);

        return (
            string.concat(svgs, headSVG),
            string.concat(
                attrs,
                ',{"trait_type": "Head Detail", "value": "',
                headTraits,
                '"}, {"trait_type": "Head Detail Color", "value": "',
                getColor(chipTraits.headDetailColor),
                '"}'
            )
        );
    }

    function getSVGStyle(
        uint8 frameColor,
        uint8 chipDetailColor,
        uint8 headShapeColor,
        uint8 headDetailColor
    ) internal pure returns (string memory) {
        return
            string.concat(
                '<style type="text/css">.f{fill:',
                getColor(frameColor),
                ";}.c{fill:",
                getColor(chipDetailColor),
                ";}.b{fill:",
                getColor(headShapeColor),
                ";}.h{fill:",
                getColor(headDetailColor),
                ";}.alpha{fill:#1477FB;}.pg{fill:#FB1467;}.e{fill-rule:evenodd;clip-rule:evenodd;}</style>"
            );
    }

    function getColor(uint8 id) internal pure returns (string memory) {
        assert(id < 5);
        string[5] memory colors = [color1, color2, color3, color4, color5];
        return colors[id];
    }

    function getHeadShape(uint8 id) internal pure returns (string memory, string memory) {
        assert(id < 3);

        return (getHeadShapeSVG(id), getHeadShapeTrait(id));
    }

    function getHeadShapeSVG(uint8 id) internal pure returns (string memory) {
        assert(id < 3);

        string[3] memory headShapeSVGs = [headShapeSVGs1, headShapeSVGs2, headShapeSVGs3];
        return headShapeSVGs[id];
    }

    function getHeadShapeTrait(uint8 id) internal pure returns (string memory) {
        assert(id < 3);
        string[3] memory headShapeTraits = [headShapeTrait1, headShapeTrait2, headShapeTrait3];
        return headShapeTraits[id];
    }
}
