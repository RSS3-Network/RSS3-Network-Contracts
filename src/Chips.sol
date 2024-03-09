// SPDX-License-Identifier: MIT
// solhint-disable quotes
pragma solidity 0.8.20;

import {IChips} from "./interfaces/IChips.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {DataTypes} from "./libraries/DataTypes.sol";
import {SVGGenerator} from "./libraries/SVGGenerator.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {ERC721} from "./base/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Chips is IChips, IErrors, Initializable, ERC721 {
    using Strings for uint256;

    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Token counter for minting.
    uint256 internal _counter;
    /// @dev Total supply of tokens.
    uint256 internal _totalSupply;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert CallerNotStaking();
        _;
    }

    /// @inheritdoc IChips
    function initialize(string memory name_, string memory symbol_, address staking_) external override initializer {
        _staking = staking_;

        __ERC721_init(name_, symbol_);
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
        DataTypes.NodeTraits memory nodeTraits = _getNodeTraits(nodeAddr);
        uint256 seed = uint256(keccak256(abi.encodePacked(nodeAddr)));
        DataTypes.ChipTraits memory chipTraits = _getChipTraitsBySeed(seed);
        chipTraits.headShapeColor = 0;
        chipTraits.headDetailColor = 0;
        (string memory imageSVG, string memory attributes) = SVGGenerator.generateSVGAndAttributes(
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
        DataTypes.NodeTraits memory nodeTraits;
        DataTypes.ChipTraits memory chipTraits;
        (nodeTraits, chipTraits) = _generateChipImage(id);

        (string memory imageSVG, string memory attributes) = SVGGenerator.generateSVGAndAttributes(
            nodeTraits,
            chipTraits
        );

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
    ) internal view returns (DataTypes.NodeTraits memory, DataTypes.ChipTraits memory) {
        (address nodeAddr, ) = IStaking(_staking).getChipsInfo(tokenId);

        DataTypes.NodeTraits memory nodeTraits = _getNodeTraits(nodeAddr);

        DataTypes.ChipTraits memory chipTraits = _getChipTraits(nodeAddr, tokenId);

        return (nodeTraits, chipTraits);
    }

    function _getNodeTraits(address nodeAddr) internal view returns (DataTypes.NodeTraits memory) {
        DataTypes.Node memory node = IStaking(_staking).getNode(nodeAddr);

        (uint8 colorCount, uint8 frameCount, uint8 chipCornerCount, uint8 chipDetailCount) = SVGGenerator
            .getNodeTraitsCount();
        uint256 nodeTraitCount = uint256(frameCount) *
            uint256(colorCount) *
            uint256(chipDetailCount) *
            uint256(colorCount) *
            uint256(chipCornerCount);

        // Chips from the same node will have the same traits
        uint256 nodeTraitId = uint256(keccak256(abi.encodePacked(nodeAddr))) % nodeTraitCount;

        DataTypes.NodeTraits memory nodeTraits = DataTypes.NodeTraits({
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

    function _getChipTraits(address nodeAddr, uint256 tokenId) internal pure returns (DataTypes.ChipTraits memory) {
        uint256 seed = uint256(keccak256(abi.encodePacked(nodeAddr, tokenId)));
        return _getChipTraitsBySeed(seed);
    }

    function _getChipTraitsBySeed(uint256 seed) internal pure returns (DataTypes.ChipTraits memory) {
        (uint8 eyeCount, uint8 mouthCount, uint8 headShapeCount, uint8 headDetailCount) = SVGGenerator
            .getChipTraitsCount();

        (uint8 colorCount, , , ) = SVGGenerator.getNodeTraitsCount();

        uint256 chipTraitCount = uint256(eyeCount) *
            uint256(mouthCount) *
            uint256(headShapeCount) *
            uint256(colorCount) *
            uint256(headDetailCount) *
            uint256(colorCount);

        uint256 chipTraitId = seed % chipTraitCount;

        DataTypes.ChipTraits memory chipTraits = DataTypes.ChipTraits({
            eyesId: _calTraitId(
                chipTraitId,
                eyeCount,
                uint256(mouthCount) *
                    uint256(headShapeCount) *
                    uint256(colorCount) *
                    uint256(headDetailCount) *
                    uint256(colorCount)
            ),
            mouthId: _calTraitId(
                chipTraitId,
                mouthCount,
                uint256(headShapeCount) * uint256(colorCount) * uint256(headDetailCount) * uint256(colorCount)
            ),
            headShapeColor: _calTraitId(
                chipTraitId,
                colorCount,
                uint256(colorCount) * uint256(headDetailCount) * uint256(colorCount)
            ),
            headShapeId: _calTraitId(chipTraitId, headShapeCount, colorCount * headDetailCount),
            headDetailColor: _calTraitId(chipTraitId, colorCount, headDetailCount),
            headDetailId: _calTraitId(chipTraitId, headDetailCount, 1)
        });

        return chipTraits;
    }

    function _calTraitId(uint256 traitId, uint8 traitCount, uint256 divisionFactor) internal pure returns (uint8) {
        return uint8((traitId / divisionFactor) % traitCount);
    }
}
