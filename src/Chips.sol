// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ErrCallerNotStaking} from "./libraries/Error.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721Consecutive
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Chips is Initializable, ERC721Consecutive {
    address internal _staking;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert ErrCallerNotStaking();
        _;
    }

    constructor() ERC721("RSS3 Chips", "Chips") {
        _disableInitializers();
    }

    function initialize(address staking_) external initializer {
        _staking = staking_;
    }

    function mint(address account, uint256 id) public onlyStaking {
        _mint(account, id);
    }

    function mintBatch(address to, uint96 batchSize) public onlyStaking returns (uint256) {
        return _mintConsecutive(to, batchSize);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
