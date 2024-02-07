// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

//import {console2 as console} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import "forge-std/console.sol";

contract ChipsTest is CommonTest {
    function setUp() public {
        _setUp();
    }

    mapping(uint256 => bool) internal _testMintMap;

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

        string memory uri = _chips.tokenURI(tokenId);
        console.log("URI: %s", uri);
    }

    function testMintBatchh() public {
        vm.prank(address(_staking));
        (uint256 start, uint256 end) = _chips.mintBatch(alice, 10);

        assertEq(_chips.balanceOf(alice), 10);
        assertEq(_chips.totalSupply(), 10);

        for (uint256 tokenId = start; tokenId <= end; tokenId++) {
            string memory uri = _chips.tokenURI(tokenId);
            console.log("URI: %s", uri);
        }
    }
}
