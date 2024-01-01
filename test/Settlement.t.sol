// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

//import {console2 as console} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";

contract SettlementTest is CommonTest {
    function setUp() public {
        _setUp();

        // transfer tokens
        _rss3.transfer(alice, _initialAmount);
        _rss3.transfer(bob, _initialAmount);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
    }
}
