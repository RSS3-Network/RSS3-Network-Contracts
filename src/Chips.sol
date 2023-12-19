// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {ErrCallerNotStaking} from "./libraries/Error.sol";

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract Chips is Initializable, ERC1155 {
    address internal _staking;

    modifier onlyStaking() {
        if (msg.sender != _staking) revert ErrCallerNotStaking();
        _;
    }

    constructor() ERC1155("") {}

    function initialize(address staking_) external initializer {
        _staking = staking_;
    }

    function setURI(string memory newuri) public onlyStaking {
        _setURI(newuri);
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
}
