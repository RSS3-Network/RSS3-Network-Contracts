// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ErrCallerNotStaking} from "./libraries/Error.sol";

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Chips is Initializable, ERC1155URIStorage {
    address internal _staking;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert ErrCallerNotStaking();
        _;
    }

    constructor() ERC1155("") {
        _disableInitializers();
    }

    function initialize(address staking_) external initializer {
        _staking = staking_;
    }

    function setURI(uint256 tokenId, string memory tokenURI) public onlyStaking {
        _setURI(tokenId, tokenURI);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyStaking {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyStaking {
        _mintBatch(to, ids, amounts, data);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return super.uri(tokenId);
    }
}
