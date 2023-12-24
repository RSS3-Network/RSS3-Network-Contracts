// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ErrCallerNotStaking} from "./libraries/Error.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/* solhint-disable comprehensive-interface */

contract Chips is Initializable, ERC721 {
    address internal _staking;

    uint256 internal _counter;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert ErrCallerNotStaking();
        _;
    }

    constructor() ERC721("RSS3 Chips", "Chips") {}

    function initialize(address staking_) external initializer {
        _staking = staking_;
    }

    function mint(address account) public onlyStaking returns (uint256 tokenId) {
        tokenId = ++_counter;
        _mint(account, tokenId);
    }

    function mintBatch(
        address to,
        uint96 batchSize
    ) public onlyStaking returns (uint256 startTokenId, uint256 endTokenId) {
        startTokenId = _counter + 1;

        uint256 tokenId = startTokenId;
        for (uint256 i = 0; i < batchSize; i++) {
            _mint(to, tokenId++);
        }
        _counter = tokenId - 1;
        endTokenId = tokenId - 1;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
