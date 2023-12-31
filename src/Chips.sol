// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IChips} from "./interfaces/IChips.sol";
import {IStaking} from "./interfaces/IStaking.sol";
import {Errors} from "./libraries/Errors.sol";
import {ERC721} from "./base/ERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Chips is IChips, Initializable, ERC721 {
    /// @dev Staking contract address.
    address internal _staking;

    /// @dev Token counter for minting.
    uint256 internal _counter;
    /// @dev Total supply of tokens.
    uint256 internal _totalSupply;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert Errors.CallerNotStaking();
        _;
    }

    /// @inheritdoc IChips
    function initialize(string memory name_, string memory symbol_, address staking_) external override initializer {
        _staking = staking_;

        super._initialize(name_, symbol_);
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
        startTokenId = _counter + 1;

        uint256 tokenId = startTokenId;
        for (uint256 i = 0; i < batchSize; i++) {
            _mint(to, tokenId++);
        }
        _counter = tokenId - 1;
        endTokenId = tokenId - 1;

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

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        (address issuer, ) = IStaking(_staking).getChipsInfo(tokenId);
        if (issuer == address(0)) {
            // TODO: set a default token URI for chips minted from public pool
            return "default token URI";
        }
        return super.tokenURI(tokenId);
    }
}
