// SPDX-License-Identifier: MIT
// solhint-disable quotes
pragma solidity 0.8.20;

import {IChips} from "./interfaces/IChips.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {ISVGGenerator} from "./interfaces/ISVGGenerator.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {ERC721} from "./base/ERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {DataTypes} from "./libraries/DataTypes.sol";

contract Chips is IChips, IErrors, Initializable, ERC721 {
    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Token counter for minting.
    uint256 internal _counter;
    /// @dev Total supply of tokens.
    uint256 internal _totalSupply;

    uint8 internal _colorCount;
    uint8 internal _frameCount;
    uint8 internal _chipDetailCount;
    uint8 internal _chipCornerCount;
    uint8 internal _eyeCount;
    uint8 internal _mouthCount;
    uint8 internal _headShapeCount;
    uint8 internal _headDetailCount;

    address internal _svgGenerator;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert CallerNotStaking();
        _;
    }

    /// @inheritdoc IChips
    function initialize(
        string memory name_,
        string memory symbol_,
        address staking_,
        address svgGenerator_
    ) external override initializer {
        _staking = staking_;

        __ERC721_init(name_, symbol_);

        _svgGenerator = svgGenerator_;

        (_colorCount, _frameCount, _chipCornerCount, _chipDetailCount) = ISVGGenerator(svgGenerator_)
            .getNodeTraitsCount();

        (_eyeCount, _mouthCount, _headShapeCount, _headDetailCount) = ISVGGenerator(svgGenerator_).getChipTraitsCount();
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
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        DataTypes.NodeTraits memory nodeTraits;
        DataTypes.ChipTraits memory chipTraits;
        (nodeTraits, chipTraits) = _generateChipImage(id);
        string memory json = string(
            abi.encodePacked(
                '{"name": "Chip #',
                id,
                '", "description": "Chip is a unique NFT that represents a node in the network.'
                'It is generated based on the node\'s address.", "image": "data:image/svg+xml;utf8,',
                _generateSVGImage(nodeTraits, chipTraits),
                '"}'
            )
        );
        return json;
    }

    /// @inheritdoc IChips
    function stakingContract() external view override returns (address) {
        return _staking;
    }

    /// @inheritdoc IChips
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function _generateChipImage(
        uint256 tokenId
    ) internal view returns (DataTypes.NodeTraits memory, DataTypes.ChipTraits memory) {
        (address nodeAddr, ) = IStaking(_staking).getChipsInfo(tokenId);
        DataTypes.Node memory node = IStaking(_staking).getNode(nodeAddr);

        uint256 nodeTraitCount = uint256(_frameCount) *
            uint256(_colorCount) *
            uint256(_chipDetailCount) *
            uint256(_colorCount) *
            uint256(_chipCornerCount);

        uint256 nodeTraitId = uint256(keccak256(abi.encodePacked(tokenId, nodeAddr))) % nodeTraitCount; // add nodeAddr?

        DataTypes.NodeTraits memory nodeTraits = DataTypes.NodeTraits({
            frameId: _calTraitId(
                nodeTraitId,
                _frameCount,
                uint256(_colorCount) * uint256(_chipDetailCount) * uint256(_colorCount) * uint256(_chipCornerCount)
            ),
            frameColor: _calTraitId(
                nodeTraitId,
                _colorCount,
                uint256(_chipDetailCount) * uint256(_colorCount) * uint256(_chipCornerCount)
            ),
            chipDetailColor: _calTraitId(nodeTraitId, _colorCount, uint256(_chipDetailCount) * uint256(_colorCount)),
            chipDetailId: _calTraitId(nodeTraitId, _chipDetailCount, _colorCount),
            // chipCornerId: uint8(nodeTraitId % _chip_corner_count) // TODO: in the future
            pgCorner: node.publicGood
        });

        uint256 chipTraitCount = uint256(_eyeCount) *
            uint256(_mouthCount) *
            uint256(_headShapeCount) *
            uint256(_colorCount) *
            uint256(_headDetailCount) *
            uint256(_colorCount);

        uint256 chipTraitId = uint256(keccak256(abi.encodePacked(tokenId))) % chipTraitCount;

        DataTypes.ChipTraits memory chipTraits = DataTypes.ChipTraits({
            eyesId: _calTraitId(
                chipTraitId,
                _eyeCount,
                uint256(_mouthCount) *
                    uint256(_headShapeCount) *
                    uint256(_colorCount) *
                    uint256(_headDetailCount) *
                    uint256(_colorCount)
            ),
            mouthId: _calTraitId(
                chipTraitId,
                _mouthCount,
                uint256(_headShapeCount) * uint256(_colorCount) * uint256(_headDetailCount) * uint256(_colorCount)
            ),
            headShapeColor: _calTraitId(
                chipTraitId,
                _colorCount,
                uint256(_colorCount) * uint256(_headDetailCount) * uint256(_colorCount)
            ),
            headShapeId: _calTraitId(chipTraitId, _headShapeCount, _colorCount * _headDetailCount),
            headDetailColor: _calTraitId(chipTraitId, _colorCount, _headDetailCount),
            headDetailId: uint8(chipTraitId % _headDetailCount)
        });

        return (nodeTraits, chipTraits);
    }

    function _generateSVGImage(
        DataTypes.NodeTraits memory nodeTraits,
        DataTypes.ChipTraits memory chipTraits
    ) internal view returns (string memory) {
        ISVGGenerator svgGenerator = ISVGGenerator(_svgGenerator);
        return svgGenerator.generateSVG(nodeTraits, chipTraits);
    }

    function _calTraitId(uint256 traitId, uint8 traitCount, uint256 divisionFactor) internal pure returns (uint8) {
        return uint8((traitId / divisionFactor) % traitCount);
    }
}
