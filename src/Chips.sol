// SPDX-License-Identifier: MIT
// solhint-disable quotes
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC721} from "./base/ERC721.sol";
import {IChips} from "./interfaces/IChips.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {Node, NodeTraits, ChipTraits, NftCardTraits, ChipVersion} from "./libraries/DataTypes.sol";
import {CallerNotStaking, BatchSizeZero} from "./libraries/Errors.sol";
import {SVGGenerator} from "./libraries/SVGGenerator.sol";
import {SVGGeneratorV2} from "./libraries/SVGGeneratorV2.sol";

contract Chips is IChips, Initializable, ERC721 {
    using Strings for uint256;

    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Token counter for minting.
    uint256 internal _counter;
    /// @dev Total supply of tokens.
    uint256 internal _totalSupply;

    /// @dev Token id that chip v2 will start with.
    uint256 internal _chipV2StartId;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert CallerNotStaking();
        _;
    }

    /// @inheritdoc IChips
    function initialize(
        string calldata name_,
        string calldata symbol_,
        address staking_
    ) external override reinitializer(2) {
        if (staking_ != address(0)) {
            _staking = staking_;
        }

        __ERC721_init(name_, symbol_);

        if (_chipV2StartId == 0) {
            _chipV2StartId = _totalSupply;
        }
    }

    /// @inheritdoc IChips
    function mint(address account) external override onlyStaking returns (uint256 tokenId) {
        tokenId = ++_counter;
        _mint(account, tokenId);

        // update total supply
        ++_totalSupply;
    }

    /// @inheritdoc IChips
    function mintBatch(
        address to,
        uint256 batchSize
    ) external override onlyStaking returns (uint256 startTokenId, uint256 endTokenId) {
        if (batchSize == 0) revert BatchSizeZero();

        startTokenId = _counter + 1;
        endTokenId = _counter + batchSize;

        // mint tokens with consecutive token IDs
        _mintConsecutive(to, startTokenId, endTokenId);

        // update token counter
        _counter += batchSize;
        // update total supply
        _totalSupply += batchSize;
    }

    /// @inheritdoc IChips
    function burn(uint256 tokenId) external override onlyStaking {
        _burn(tokenId);

        _totalSupply--;
    }

    /// @inheritdoc IChips
    function stakingContract() external view override returns (address) {
        return _staking;
    }

    /// @inheritdoc IChips
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function nodeImageAndAttributesURI(address nodeAddr) external view override returns (string memory) {
        NodeTraits memory nodeTraits = _getNodeTraits(nodeAddr, ChipVersion.V2);
        uint256 seed = uint256(keccak256(abi.encodePacked(nodeAddr)));
        (ChipTraits memory chipTraits, ) = _getOtherTraitsBySeed(seed, ChipVersion.V2);
        chipTraits.headShapeColor = 0;
        chipTraits.headDetailColor = 0;
        (string memory imageSVG, string memory attributes) = SVGGeneratorV2.generateSVGAndAttributes(
            nodeTraits,
            chipTraits
        );

        string memory json = string.concat(
            '{"name": "Node Avatar", "image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(imageSVG)),
            '", "attributes": [',
            attributes,
            "]}"
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(string.concat(json))));
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        NodeTraits memory nodeTraits;
        ChipTraits memory chipTraits;
        NftCardTraits memory nftCardTraits;

        (nodeTraits, chipTraits, nftCardTraits) = _generateChipImage(id);

        (string memory imageSVG, string memory attributes) = _getChipVersion(id) == ChipVersion.V2
            ? SVGGeneratorV2.generateSVGAndAttributes(nodeTraits, chipTraits, nftCardTraits)
            : SVGGenerator.generateSVGAndAttributes(nodeTraits, chipTraits);

        string memory json = string.concat(
            '{"name": "Open Chips #',
            id.toString(),
            '", "description": "Chip Monsters are unique creatures living in the RSS3 Network, '
            "each one special because of where it was born. They represent the idea of FREE and "
            "OPEN INFORMATION, thriving in a world that values sharing and being different. "
            "These Chip Monsters are more than just digital; they symbolize the excitement and "
            "importance of being unique in a connected digital world.",
            '","image":"data:image/svg+xml;base64,',
            Base64.encode(bytes(imageSVG)),
            '", "attributes": [',
            attributes,
            "]}"
        );

        return string.concat("data:application/json;base64,", Base64.encode(bytes(string.concat(json))));
    }

    function _generateChipImage(
        uint256 tokenId
    ) internal view returns (NodeTraits memory, ChipTraits memory, NftCardTraits memory) {
        (address nodeAddr, uint256 tokens, ) = IStaking(_staking).getChipInfo(tokenId);

        ChipVersion version = _getChipVersion(tokenId);

        NodeTraits memory nodeTraits = _getNodeTraits(nodeAddr, version);

        (ChipTraits memory chipTraits, uint8 nftCardId) = _getOtherTraits(nodeAddr, tokenId);

        Node memory node = IStaking(_staking).getNode(nodeAddr);
        Node memory poolNode = node.publicGood ? IStaking(_staking).getPublicPool() : node;

        NftCardTraits memory nftCardTraits = NftCardTraits({
            nftCardId: nftCardId,
            tokenId: tokenId,
            chipTokens: tokens,
            nodeAddr: nodeAddr,
            stakingPoolTokens: poolNode.stakingPoolTokens,
            operationPoolTokens: poolNode.operationPoolTokens
        });

        return (nodeTraits, chipTraits, nftCardTraits);
    }

    function _getNodeTraits(address nodeAddr, ChipVersion version) internal view returns (NodeTraits memory) {
        Node memory node = IStaking(_staking).getNode(nodeAddr);

        (uint8 colorCount, uint8 frameCount, uint8 chipCornerCount, uint8 chipDetailCount) = version == ChipVersion.V1
            ? SVGGenerator.getNodeTraitsCount()
            : SVGGeneratorV2.getNodeTraitsCount();

        uint256 nodeTraitCount = uint256(frameCount) *
            uint256(colorCount) *
            uint256(chipDetailCount) *
            uint256(colorCount) *
            uint256(chipCornerCount);

        // Chips from the same node will have the same traits
        uint256 nodeTraitId = uint256(keccak256(abi.encodePacked(nodeAddr))) % nodeTraitCount;

        NodeTraits memory nodeTraits = NodeTraits({
            frameId: _calTraitId(
                nodeTraitId,
                frameCount,
                uint256(colorCount) * uint256(chipDetailCount) * uint256(colorCount) * uint256(chipCornerCount)
            ),
            frameColor: _calTraitId(
                nodeTraitId,
                colorCount,
                uint256(chipDetailCount) * uint256(colorCount) * uint256(chipCornerCount)
            ),
            chipDetailColor: _calTraitId(nodeTraitId, colorCount, uint256(chipDetailCount) * uint256(colorCount)),
            chipDetailId: _calTraitId(nodeTraitId, chipDetailCount, colorCount),
            chipCornerId: _calTraitId(nodeTraitId, chipCornerCount, 1),
            pg: node.publicGood,
            alpha: node.alpha
        });

        return nodeTraits;
    }

    function _getOtherTraits(address nodeAddr, uint256 tokenId) internal view returns (ChipTraits memory, uint8) {
        uint256 seed = uint256(keccak256(abi.encodePacked(nodeAddr, tokenId)));
        ChipVersion version = _getChipVersion(tokenId);
        return _getOtherTraitsBySeed(seed, version);
    }

    function _getChipVersion(uint256 tokenId) internal view returns (ChipVersion) {
        return _chipV2StartId < tokenId ? ChipVersion.V2 : ChipVersion.V1;
    }

    function _getOtherTraitsBySeed(
        uint256 seed,
        ChipVersion version
    ) internal pure returns (ChipTraits memory, uint8 nftCardId) {
        uint8 eyeCount;
        uint8 mouthCount;
        uint8 headShapeCount;
        uint8 headDetailCount;
        uint8 colorCount;
        uint8 nftCardCount;

        if (version == ChipVersion.V1) {
            (eyeCount, mouthCount, headShapeCount, headDetailCount) = SVGGenerator.getChipTraitsCount();
            (colorCount, , , ) = SVGGenerator.getNodeTraitsCount();
            nftCardCount = 1; // V1 doesn't have nftCardCount, set to 1
        } else {
            (eyeCount, mouthCount, headShapeCount, headDetailCount, nftCardCount) = SVGGeneratorV2.getChipTraitsCount();
            (colorCount, , , ) = SVGGeneratorV2.getNodeTraitsCount();
        }

        uint256 chipTraitCount = uint256(eyeCount) *
            (mouthCount) *
            (headShapeCount) *
            (colorCount) *
            (headDetailCount) *
            (colorCount) *
            (nftCardCount);

        uint256 chipTraitId = seed % chipTraitCount;

        return (
            _getChipTraitsByCount(
                chipTraitId,
                eyeCount,
                mouthCount,
                headShapeCount,
                headDetailCount,
                colorCount,
                nftCardCount
            ),
            _calTraitId(chipTraitId, nftCardCount, 1)
        );
    }

    function _getChipTraitsByCount(
        uint256 chipTraitId,
        uint8 eyeCount,
        uint8 mouthCount,
        uint8 headShapeCount,
        uint8 headDetailCount,
        uint8 colorCount,
        uint8 nftCardCount
    ) internal pure returns (ChipTraits memory) {
        uint256 factor = uint256(mouthCount) *
            uint256(headShapeCount) *
            uint256(colorCount) *
            uint256(headDetailCount) *
            uint256(colorCount) *
            uint256(nftCardCount);

        return (
            ChipTraits({
                eyesId: _calTraitId(chipTraitId, eyeCount, factor),
                mouthId: _calTraitId(chipTraitId, mouthCount, factor / uint256(mouthCount)),
                headShapeId: _calTraitId(
                    chipTraitId,
                    headShapeCount,
                    (factor / uint256(mouthCount)) / uint256(headShapeCount)
                ),
                headShapeColor: _calTraitId(
                    chipTraitId,
                    colorCount,
                    (factor / uint256(mouthCount)) / uint256(headShapeCount) / uint256(colorCount)
                ),
                headDetailId: _calTraitId(
                    chipTraitId,
                    headDetailCount,
                    (factor / uint256(mouthCount)) /
                        uint256(headShapeCount) /
                        uint256(colorCount) /
                        uint256(headDetailCount)
                ),
                headDetailColor: _calTraitId(
                    chipTraitId,
                    colorCount,
                    (factor / uint256(mouthCount)) /
                        uint256(headShapeCount) /
                        uint256(colorCount) /
                        uint256(headDetailCount) /
                        uint256(colorCount)
                )
            })
        );
    }

    function _calTraitId(uint256 traitId, uint8 traitCount, uint256 divisionFactor) internal pure returns (uint8) {
        return uint8((traitId / divisionFactor) % traitCount);
    }
}
