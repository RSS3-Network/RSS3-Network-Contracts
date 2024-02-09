// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

import {DataTypes} from "./DataTypes.sol";
import {Eyes} from "./SVG/Eyes.sol";
import {ChipDetail} from "./SVG/ChipDetail.sol";
import {Head} from "./SVG/Head.sol";
import {Mouths} from "./SVG/Mouths.sol";
import {Frame} from "./SVG/Frame.sol";

library SVGGenerator {
    string public constant baseSVGHead =
        '<?xml version="1.0" encoding="utf-8"?><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 100 100" style="enable-background:new 0 0 100 100;background-color:black;" xml:space="preserve">';

    string public constant baseSVGTail = "</svg>";

    string public constant color1 = "#DEE5D9";
    string public constant color2 = "#FB1467";
    string public constant color3 = "#1477FB";
    string public constant color4 = "#FFD600";
    string public constant color5 = "#31C040";

    string public constant baseHeadsSVGs1 =
        '<polygon class="st-base-head" points="72,48 72,64 70,64 70,66 68,66 68,68 64,68 64,70 60,70 60,72 40,72 40,70 36,70 36,68 32,68 32,66   30,66 30,64 28,64 28,48 30,48 30,46 32,46 32,44 68,44 68,46 70,46 70,48 "/>';
    string public constant baseHeadsSVGs2 =
        '<polygon class="st-base-head" points="72,44 72,68 70,68 70,70 68,70 68,72 32,72 32,70 30,70 30,68 28,68 28,44 "/>';
    string public constant baseHeadsSVGs3 =
        '<polygon class="st-base-head" points="72,46 72,64 70,64 70,66 68,66 68,68 66,68 66,70 64,70 64,72 36,72 36,70 34,70 34,68 32,68 32,66   30,66 30,64 28,64 28,46 30,46 30,44 70,44 70,46 "/>';

    function generateSVG(
        DataTypes.NodeTraits memory nodeTraits,
        DataTypes.ChipTraits memory chipTraits
    ) external pure returns (string memory) {
        string memory styleSVG = getSVGStyle(
            nodeTraits.frameColor,
            nodeTraits.chipDetailColor,
            chipTraits.headShapeColor,
            chipTraits.headDetailColor
        );

        string memory corner = nodeTraits.pgCorner ? Frame.pgSVG : Frame.alphaSVG;

        string[9] memory frameSVGs = [
            Frame.frameSVGs1,
            Frame.frameSVGs2,
            Frame.frameSVGs3,
            Frame.frameSVGs4,
            Frame.frameSVGs5,
            Frame.frameSVGs6,
            Frame.frameSVGs7,
            Frame.frameSVGs8,
            Frame.frameSVGs9
        ];

        string[11] memory chipDetailSVGs = [
            ChipDetail.chipDetailSVGs1,
            ChipDetail.chipDetailSVGs2,
            ChipDetail.chipDetailSVGs3,
            ChipDetail.chipDetailSVGs4,
            ChipDetail.chipDetailSVGs5,
            ChipDetail.chipDetailSVGs6,
            ChipDetail.chipDetailSVGs7,
            ChipDetail.chipDetailSVGs8,
            ChipDetail.chipDetailSVGs9,
            ChipDetail.chipDetailSVGs10,
            ChipDetail.chipDetailSVGs11
        ];

        string memory innerSVG1 = string(
            abi.encodePacked(
                baseSVGHead,
                styleSVG,
                frameSVGs[nodeTraits.frameId % 9],
                chipDetailSVGs[nodeTraits.chipDetailId % 11],
                // chipDetailSVGs[nodeTraits.chipDetailId % chipDetailSVGs.length], chipCorner
                corner
            )
        );

        string memory innerSVG2 = getChipTraitsInnerSVG(chipTraits);

        return string(abi.encodePacked(innerSVG1, innerSVG2));
    }

    function getChipTraitsInnerSVG(DataTypes.ChipTraits memory chipTraits) internal pure returns (string memory) {
        string[3] memory baseHeadsSVGs = [baseHeadsSVGs1, baseHeadsSVGs2, baseHeadsSVGs3];

        string[18] memory eyesSVGs = [
            Eyes.eyesSVGs1,
            Eyes.eyesSVGs2,
            Eyes.eyesSVGs3,
            Eyes.eyesSVGs4,
            Eyes.eyesSVGs5,
            Eyes.eyesSVGs6,
            Eyes.eyesSVGs7,
            Eyes.eyesSVGs8,
            Eyes.eyesSVGs9,
            Eyes.eyesSVGs10,
            Eyes.eyesSVGs11,
            Eyes.eyesSVGs12,
            Eyes.eyesSVGs13,
            Eyes.eyesSVGs14,
            Eyes.eyesSVGs15,
            Eyes.eyesSVGs16,
            Eyes.eyesSVGs17,
            Eyes.eyesSVGs18
        ];

        string[19] memory mouthsSVGs = [
            Mouths.mouthsSVGs1,
            Mouths.mouthsSVGs2,
            Mouths.mouthsSVGs3,
            Mouths.mouthsSVGs4,
            Mouths.mouthsSVGs5,
            Mouths.mouthsSVGs6,
            Mouths.mouthsSVGs7,
            Mouths.mouthsSVGs8,
            Mouths.mouthsSVGs9,
            Mouths.mouthsSVGs10,
            Mouths.mouthsSVGs11,
            Mouths.mouthsSVGs12,
            Mouths.mouthsSVGs13,
            Mouths.mouthsSVGs14,
            Mouths.mouthsSVGs15,
            Mouths.mouthsSVGs16,
            Mouths.mouthsSVGs17,
            Mouths.mouthsSVGs18,
            Mouths.mouthsSVGs19
        ];

        string[16] memory headSVGs = [
            Head.headSVGs1,
            Head.headSVGs2,
            Head.headSVGs3,
            Head.headSVGs4,
            Head.headSVGs5,
            Head.headSVGs6,
            Head.headSVGs7,
            Head.headSVGs8,
            Head.headSVGs9,
            Head.headSVGs10,
            Head.headSVGs11,
            Head.headSVGs12,
            Head.headSVGs13,
            Head.headSVGs14,
            Head.headSVGs15,
            Head.headSVGs16
        ];

        string memory innerSVG2 = string(
            abi.encodePacked(
                baseHeadsSVGs[chipTraits.headShapeId % 3],
                eyesSVGs[chipTraits.eyesId % 18],
                mouthsSVGs[chipTraits.mouthId % 19],
                headSVGs[chipTraits.headDetailId % 16],
                baseSVGTail
            )
        );
        return innerSVG2;
    }

    function getSVGStyle(
        uint8 frameColor,
        uint8 chipDetailColor,
        uint8 headShapeColor,
        uint8 headDetailColor
    ) internal pure returns (string memory) {
        string[5] memory colors = [color1, color2, color3, color4, color5];
        return
            string(
                abi.encodePacked(
                    '<style type="text/css">.st-frames{fill:',
                    colors[frameColor],
                    ";}.st-chip-detail{fill:",
                    colors[chipDetailColor],
                    ";}.st-base-head{fill:",
                    colors[headShapeColor],
                    ";}.st-head{fill:",
                    colors[headDetailColor],
                    ";}.st-alpha{fill:#1477FB;}.st-pg{fill:#FB1467;}.st-head-evenodd{fill-rule:evenodd;clip-rule:evenodd;}</style>"
                )
            );
    }

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
}
