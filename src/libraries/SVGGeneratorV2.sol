// SPDX-License-Identifier: MIT
// solhint-disable quotes,max-line-length
pragma solidity 0.8.20;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {LibString} from "solady/utils/LibString.sol";
import {NodeTraits, ChipTraits, NftCardTraits} from "./DataTypes.sol";
import {Fonts1} from "./Fonts/Fonts1.sol";
import {Fonts2} from "./Fonts/Fonts2.sol";
import {ChipCorners} from "./SVGsV2/ChipCorners.sol";
import {ChipDetails} from "./SVGsV2/ChipDetails.sol";
import {ChipFrames} from "./SVGsV2/ChipFrames.sol";
import {Eyes} from "./SVGsV2/Eyes.sol";
import {HeadDetails} from "./SVGsV2/HeadDetails.sol";
import {HeadShapes} from "./SVGsV2/HeadShapes.sol";
import {Mouths} from "./SVGsV2/Mouths.sol";
import {NftCards} from "./SVGsV2/NftCards.sol";

library SVGGeneratorV2 {
    using Strings for uint256;
    using Strings for address;

    string public constant baseSVGTail = "</svg>";

    string public constant color1 = "#DEE5D9";
    string public constant color2 = "#FB1467";
    string public constant color3 = "#1477FB";
    string public constant color4 = "#FFD600";
    string public constant color5 = "#31C040";

    function getNodeTraitsCount() external pure returns (uint8, uint8, uint8, uint8) {
        return (
            5, // uint8(_colors.length),
            9, // uint8(_chipSVGs.length),
            7, // uint8(_ChipCornersVGs.length),
            11 // uint8(_chipDetailSVGs.length)
        );
    }

    function getChipTraitsCount() external pure returns (uint8, uint8, uint8, uint8, uint8) {
        return (
            18, // uint8(_eyesSVGs.length),
            17, //uint8(_mouthsSVGs.length),
            3, //uint8(_baseHeadsSVGs.length),
            16, //uint8(_headSVGs.length),
            5 // uint8(_nftCardsSVGs.length)
        );
    }

    function generateSVGAndAttributes(
        NodeTraits calldata nodeTraits,
        ChipTraits calldata chipTraits,
        NftCardTraits calldata nftCardTraits
    ) external pure returns (string memory, string memory) {
        string memory styleSVG = getSVGStyle(
            nodeTraits.frameColor,
            nodeTraits.chipDetailColor,
            chipTraits.headShapeColor,
            chipTraits.headDetailColor,
            true
        );

        (string memory nftCard, string memory nftCardTrait) = nodeTraits.pg
            ? (NftCards.getPublicGoodNftCard(), "Public Good Node")
            : nodeTraits.alpha
                ? (NftCards.getAlphaNftCard(), "Alpha Node")
                : NftCards.getNftCard(nftCardTraits.nftCardId);

        (string memory nodeSVG, string memory attributes1) = getNodeTraitsInnerSVGAndAttributes(nodeTraits);

        (string memory chipSVG, string memory attributes2) = getChipTraitsInnerSVGAndAttributes(chipTraits);

        return (
            string.concat(
                _getSVGHead(124, 182),
                styleSVG,
                getNftCardSvgs(nftCard, nftCardTraits),
                '<g transform="translate(12, 41)">',
                nodeSVG,
                chipSVG,
                "</g>",
                baseSVGTail
            ),
            string.concat(attributes1, ",", attributes2, ', {"trait_type": "NFT Card", "value": "', nftCardTrait, '"}')
        );
    }

    function generateSVGAndAttributes(
        NodeTraits calldata nodeTraits,
        ChipTraits calldata chipTraits
    ) external pure returns (string memory, string memory) {
        string memory styleSVG = getSVGStyle(
            nodeTraits.frameColor,
            nodeTraits.chipDetailColor,
            chipTraits.headShapeColor,
            chipTraits.headDetailColor,
            false
        );

        (string memory nodeSVG, string memory attributes1) = getNodeTraitsInnerSVGAndAttributes(nodeTraits);

        (string memory chipSVG, string memory attributes2) = getChipTraitsInnerSVGAndAttributes(chipTraits);

        return (
            string.concat(_getSVGHead(100, 100), styleSVG, nodeSVG, chipSVG, baseSVGTail),
            string.concat(attributes1, ",", attributes2)
        );
    }

    function getNftCardSvgs(
        string memory nftCard,
        NftCardTraits calldata nftCardTraits
    ) internal pure returns (string memory) {
        (string memory addrPart1, string memory addrPart2) = _splitAddress(nftCardTraits.nodeAddr);

        uint256 opTokens = nftCardTraits.operationPoolTokens / 1 ether;
        string memory ops = string.concat(
            '<text font-family="AuxMono" x="21" y="3.5" font-size="3.8" letter-spacing="-.38" dominant-baseline="middle" text-anchor="middle" transform="translate(19 158)" fill="url(#a)"> OPS: ',
            opTokens > 1000 ? (opTokens / 1000).toString() : opTokens.toString(),
            opTokens > 1000 ? "K</text>" : "</text>"
        );

        uint256 stTokens = nftCardTraits.stakingPoolTokens / 1 ether;
        string memory sps = string.concat(
            '<text font-family="AuxMono" x="21" y="3.5" font-size="3.8" letter-spacing="-.38" dominant-baseline="middle" text-anchor="middle" transform="translate(63 158)" fill="url(#a)"> SPS: ',
            stTokens > 1000 ? (stTokens / 1000).toString() : stTokens.toString(),
            stTokens > 1000 ? "K</text>" : "</text>"
        );

        return
            string.concat(
                '<g transform="translate(6,6)">',
                nftCard,
                '<text x="10" y="27" fill="url(#a)" font-size="6" font-family="AuxMono">ID:',
                nftCardTraits.tokenId.toString(),
                "</text>",
                '<g fill="#000" font-size="6" font-family="AuxMono"><text text-anchor="end" y="-1em" transform="translate(106 14.53)">',
                (nftCardTraits.chipTokens / 1 ether).toString(),
                '</text><text text-anchor="end" transform="translate(106 14.53)">$RSS3</text></g>',
                '<g fill="url(#a)" font-size="5" font-family="AuxMono"><text x="43.5" y="6.1" letter-spacing="-.38" dominant-baseline="middle" text-anchor="middle" transform="translate(19 140)">',
                addrPart1,
                '</text><text x="43.5" y="9.9" letter-spacing="-.38" dominant-baseline="middle" transform="translate(-20 140)">',
                addrPart2,
                "</text></g>",
                ops,
                sps,
                "</g>"
            );
    }

    // get node traits and nft card trait
    function getNodeTraitsInnerSVGAndAttributes(
        NodeTraits memory nodeTraits
    ) internal pure returns (string memory, string memory) {
        string memory svgParts = "";
        string memory attributes = "";

        (svgParts, attributes) = getChipFrame(svgParts, attributes, nodeTraits);
        (svgParts, attributes) = addChipDetail(svgParts, attributes, nodeTraits);

        (string memory corner, string memory cornerTrait) = nodeTraits.pg
            ? (ChipCorners.getPublicGoodChipCorner(), "Public Good Node")
            : nodeTraits.alpha
                ? (ChipCorners.getAlphaChipCorner(), "Alpha Node")
                : ChipCorners.getChipCorner(nodeTraits.chipCornerId);

        string memory innerSVG1 = string.concat(svgParts, corner);

        string memory attributes1 = string.concat(
            attributes,
            ', {"trait_type": "Corner", "value": "',
            cornerTrait,
            '"}'
        );

        return (innerSVG1, attributes1);
    }

    function getChipTraitsInnerSVGAndAttributes(
        ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory svgParts, string memory headShapeTrait) = HeadShapes.getHeadShape(chipTraits.headShapeId % 3);

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
        ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory eyesSVG, string memory eyesTrait) = Eyes.getEye(chipTraits.eyesId);

        return (
            string.concat(svgs, eyesSVG),
            string.concat(attrs, ',{"trait_type": "Eyes", "value": "', eyesTrait, '"}')
        );
    }

    function addMouth(
        string memory svgs,
        string memory attrs,
        ChipTraits memory chipTraits
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
        ChipTraits memory chipTraits
    ) internal pure returns (string memory, string memory) {
        (string memory headSVG, string memory headTraits) = HeadDetails.getHeadDetail(chipTraits.headDetailId);

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

    function getChipFrame(
        string memory svgs,
        string memory attrs,
        NodeTraits memory nodeTraits
    ) internal pure returns (string memory, string memory) {
        (string memory chipSVGs, string memory chipTrait) = ChipFrames.getChipFrame(nodeTraits.frameId);

        return (
            string.concat(svgs, chipSVGs),
            string.concat(
                attrs,
                '{"trait_type": "Chip", "value": "',
                chipTrait,
                '"}, {"trait_type": "Frame Color", "value": "',
                getColor(nodeTraits.frameColor),
                '"}'
            )
        );
    }

    function addChipDetail(
        string memory svgs,
        string memory attrs,
        NodeTraits memory nodeTraits
    ) internal pure returns (string memory, string memory) {
        (string memory chipSVGs, string memory chipTrait) = ChipDetails.getChipDetail(nodeTraits.chipDetailId);

        return (
            string.concat(svgs, chipSVGs),
            string.concat(
                attrs,
                ',{"trait_type": "Chip Detail", "value": "',
                chipTrait,
                '"}, {"trait_type": "Chip Detail Color", "value": "',
                getColor(nodeTraits.chipDetailColor),
                '"}'
            )
        );
    }

    function getSVGStyle(
        uint8 frameColor,
        uint8 chipDetailColor,
        uint8 headShapeColor,
        uint8 headDetailColor,
        bool includeFonts
    ) internal pure returns (string memory) {
        string memory fontStr = includeFonts ? string.concat(Fonts1.getFont(), Fonts2.getFont()) : "";
        return
            string.concat(
                '<style type="text/css">',
                fontStr,
                ".b{fill:",
                getColor(frameColor),
                ";}.c{fill:",
                getColor(chipDetailColor),
                ";}.d{fill:",
                getColor(headShapeColor),
                ";}.e{fill:",
                getColor(headDetailColor),
                ";}</style>"
            );
    }

    function _getSVGHead(uint256 w, uint256 h) internal pure returns (string memory) {
        return
            string.concat(
                '<?xml version="1.0" encoding="utf-8"?><svg version="1.1" id="Layer_1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" x="0px" y="0px" viewBox="0 0 ',
                w.toString(),
                " ",
                h.toString(),
                '" style="enable-background:new 0 0 ',
                w.toString(),
                " ",
                h.toString(),
                ';background-color:black;" xml:space="preserve">'
            );
    }

    function getColor(uint8 id) internal pure returns (string memory) {
        assert(id < 5);
        string[5] memory colors = [color1, color2, color3, color4, color5];
        return colors[id];
    }

    function _splitAddress(address addr) internal pure returns (string memory, string memory) {
        string memory addrHex = addr.toHexString();
        return (LibString.slice(addrHex, 0, 25), LibString.slice(addrHex, 26, 42));
    }

    function _getSlice(uint256 begin, uint256 end, string memory text) internal pure returns (string memory) {
        bytes memory a = new bytes(end - begin);
        for (uint256 i = 0; i < end - begin; i++) {
            a[i] = bytes(text)[i + begin];
        }
        return string(a);
    }
}
