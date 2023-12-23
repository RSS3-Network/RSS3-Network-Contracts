// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ErrCallerNotStaking} from "./libraries/Error.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {
    ERC721Consecutive
} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";

contract Chips is Initializable, ERC721AUpgradeable {
    address internal _staking;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert ErrCallerNotStaking();
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address staking,
        string calldata name,
        string calldata symbol
    ) external initializerERC721A initializer {
        _staking = staking;

        __ERC721A_init(name, symbol);
    }

    function mintBatch(address to, uint256 quantity) public onlyStaking {
        _mint(to, quantity);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }
}
