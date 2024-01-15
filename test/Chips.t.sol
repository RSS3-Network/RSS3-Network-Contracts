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
        uint256 tokenId = _internalChipsTest.mint(alice);

        assertEq(_internalChipsTest.ownerOf(tokenId), alice);
        assertEq(_internalChipsTest.balanceOf(alice), 1);
        assertEq(_internalChipsTest.totalSupply(), 1);

        // test random traits
        uint256[] memory seeds = _internalChipsTest.getChipImageSeeds(tokenId);

        uint256 traitsCount = _internalChipsTest.getTraitsCount();

        console.log(tokenId, traitsCount);
        assertEq(seeds.length, traitsCount);

        for (uint256 i = 0; i < traitsCount; i++) {
            assertEq(_testMintMap[i], false);
            console.log(seeds[i]);
            _testMintMap[i] = true;
        }
    }

    function testMintBatchh() public {
        vm.prank(address(_staking));
        (uint256 start, uint256 end) = _internalChipsTest.mintBatch(alice, 10);

        assertEq(_internalChipsTest.balanceOf(alice), 10);
        assertEq(_internalChipsTest.totalSupply(), 10);

        for (uint256 tokenId = start; tokenId <= end; tokenId++) {
            assertEq(_internalChipsTest.ownerOf(tokenId), alice);

            // test random traits
            uint256[] memory seeds = _internalChipsTest.getChipImageSeeds(tokenId);

            uint256 traitsCount = _internalChipsTest.getTraitsCount();

            assertEq(seeds.length, traitsCount);

            for (uint256 i = 0; i < traitsCount; i++) {
                uint256 seed = seeds[i];
                assertEq(_testMintMap[seed], false);
                _testMintMap[seed] = true;
            }
        }
    }
}
