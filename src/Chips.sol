// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IChips} from "./interfaces/IChips.sol";
import {Errors} from "./libraries/Errors.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Chips is IChips, Initializable, ERC721 {
    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Token counter for minting.
    uint256 internal _counter;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert Errors.CallerNotStaking();
        _;
    }

    constructor() ERC721("RSS3 Chips", "Chips") {}

    /// @inheritdoc IChips
    function initialize(address staking_) external override initializer {
        _staking = staking_;
    }

    /// @inheritdoc IChips
    function mint(address account) external override onlyStaking returns (uint256 tokenId) {
        tokenId = ++_counter;
        _mint(account, tokenId);
    }

    /// @inheritdoc IChips
    function mintBatch(
        address to,
        uint256 batchSize
    ) external override onlyStaking returns (uint256 startTokenId, uint256 endTokenId) {
        startTokenId = _counter + 1;

        uint256 tokenId = startTokenId;
        for (uint256 i = 0; i < batchSize; i++) {
            _mint(to, tokenId++);
        }
        _counter = tokenId - 1;
        endTokenId = tokenId - 1;
    }

    /// @inheritdoc IChips
    function burn(uint256 tokenId) external override onlyStaking {
        _burn(tokenId);
    }

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
