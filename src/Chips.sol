// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IChips} from "./interfaces/IChips.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {ERC721} from "./base/ERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Chips is IChips, IErrors, Initializable, ERC721 {
    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Token counter for minting.
    uint256 internal _counter;
    /// @dev Total supply of tokens.
    uint256 internal _totalSupply;

    uint256 internal _randomTraitCount;

    mapping(uint256 tokenId => uint256[] randomNumbers) internal _chipImageSeeds;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert CallerNotStaking();
        _;
    }

    /// @inheritdoc IChips
    function initialize(string memory name_, string memory symbol_, address staking_) external override initializer {
        _staking = staking_;

        __ERC721_init(name_, symbol_);

        _randomTraitCount = 3; // TODO: CHANGE ME WHEN DEPLOY
    }

    /// @inheritdoc IChips
    function mint(address account) external override onlyStaking returns (uint256 tokenId) {
        tokenId = ++_counter;
        _mint(account, tokenId);

        // update total supply
        ++_totalSupply;

        _setRandomTraits(tokenId);
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

        for (uint256 id = startTokenId; id <= endTokenId; id++) {
            _setRandomTraits(id);
        }

        // update token counter
        _counter += batchSize;
        // update total supply
        _totalSupply += batchSize;
    }

    /// @inheritdoc IChips
    function burn(uint256 tokenId) external override onlyStaking {
        _burn(tokenId);
    }

    /// @inheritdoc IChips
    function stakingContract() external view override returns (address) {
        return _staking;
    }

    /// @inheritdoc IChips
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function _setRandomTraits(uint256 tokenId) internal {
        for (uint256 i = 0; i < _randomTraitCount; i++) {
            uint256 n = uint256(keccak256(abi.encodePacked(block.prevrandao, block.timestamp, tokenId, i)));
            // TODO: if gas is too much, we can save block.prevrandao, block.timestamp and tokenId
            // and calculate in _getRandomTraits
            _chipImageSeeds[tokenId].push(n);
        }
    }

    function _getRandomTraits(uint256 tokenId) internal view returns (uint256[] memory) {
        return _chipImageSeeds[tokenId];
    }
}
