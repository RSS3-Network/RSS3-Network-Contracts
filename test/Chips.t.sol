// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

//import {console2 as console} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {TestEvents} from "test/helpers/TestEvents.sol";

contract ChipsTest is CommonTest {
    function setUp() public {
        _setUp();
    }

    function testCheckSetupStatus() public {
        assertEq(_chips.name(), chipsName);
        assertEq(_chips.symbol(), chipsSymbol);
    }

    function testMint() public {
        vm.prank(address(_staking));
        uint256 tokenId = _chips.mint(alice);

        assertEq(_chips.ownerOf(tokenId), alice);
        assertEq(_chips.balanceOf(alice), 1);
        assertEq(_chips.totalSupply(), 1);
    }
}
