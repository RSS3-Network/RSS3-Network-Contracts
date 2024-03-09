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

    function testMintBatchFail() public {
        vm.expectRevert(abi.encodeWithSelector(BatchSizeZero.selector));
        vm.prank(address(_staking));
        _chips.mintBatch(alice, 0);
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

    function testApprove() public {
        vm.prank(address(_staking));
        uint256 tokenId = _chips.mint(alice);

        vm.prank(alice);
        _chips.approve(bob, tokenId);

        assertEq(_chips.getApproved(tokenId), bob);
    }

    function testSetApprovalForAll() public {
        vm.prank(alice);
        _chips.setApprovalForAll(bob, true);

        assertEq(_chips.isApprovedForAll(alice, bob), true);
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
            "Chip Monsters are unique creatures living in the RSS3 Network, each one special because of where it was born. They represent the idea of FREE and OPEN INFORMATION, thriving in a world that values sharing and being different. These Chip Monsters are more than just digital; they symbolize the excitement and importance of being unique in a connected digital world."
        );
    }
}
