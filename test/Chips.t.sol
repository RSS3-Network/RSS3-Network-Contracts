// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console,max-line-length
pragma solidity 0.8.20;

import {stdJson} from "forge-std/StdJson.sol";
import {LibString} from "solady/utils/LibString.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {Base64} from "solady/utils/Base64.sol";

contract ChipsTest is CommonTest {
    using stdJson for string;

    function setUp() public {
        _setUp();
    }

    function testCheckSetupStatus() public {
        assertEq(_chips.name(), chipsName);
        assertEq(_chips.symbol(), chipsSymbol);
        assertEq(_chips.stakingContract(), address(_staking));
    }

    function testMint() public {
        vm.prank(address(_staking));
        uint256 tokenId = _chips.mint(alice);

        assertEq(_chips.ownerOf(tokenId), alice);
        assertEq(_chips.balanceOf(alice), 1);
        assertEq(_chips.totalSupply(), 1);
    }

    function testMintBatch() public {
        vm.prank(address(_staking));
        (uint256 start, uint256 end) = _chips.mintBatch(alice, 10);

        assertEq(_chips.balanceOf(alice), 10);
        assertEq(_chips.totalSupply(), 10);

        for (uint256 tokenId = start; tokenId <= end; tokenId++) {
            assertEq(_chips.ownerOf(tokenId), alice);
        }
    }

    function testBurn() public {
        vm.startPrank(address(_staking));
        (uint256 start, uint256 end) = _chips.mintBatch(alice, 10);

        uint256 totalSupply = _chips.totalSupply();
        assertEq(_chips.totalSupply(), 10);

        for (uint256 tokenId = start; tokenId <= end; tokenId++) {
            _chips.burn(tokenId);

            assertEq(_chips.totalSupply(), --totalSupply);
        }
        vm.stopPrank();
    }

    function testTokenURI() public {
        _createNode(alice);

        vm.deal(alice, 100000 ether);

        vm.prank(alice);
        _staking.stake{value: 5000 ether}(alice);

        string memory tokenURI = _chips.tokenURI(1);
        string memory base64prefix = "data:application/json;base64,";
        string memory decodedTokenURI = string(Base64.decode(LibString.slice(tokenURI, bytes(base64prefix).length)));

        assertEq(decodedTokenURI.readString(".name"), "Chip #1");
        assertEq(
            decodedTokenURI.readString(".description"),
            "Chip is a unique NFT that represents a node in the network. It is generated based on the node's address and token ID."
        );
    }
}
