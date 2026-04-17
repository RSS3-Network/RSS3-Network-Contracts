// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.24;

import {Staking} from "../src/Staking.sol";
import {Utilizer} from "../src/Utilizer.sol";
import {Const} from "../src/libraries/Const.sol";
import {Node} from "../src/libraries/DataTypes.sol";
import {CommonTest} from "./helpers/CommonTest.sol";
import {
    TransparentUpgradeableProxy as Proxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IProxy {
    function upgradeTo(address) external;
}

contract ExchangeViewTest is CommonTest {
    address payable public stakingAddress = payable(0x28F14d917fddbA0c1f2923C406952478DfDA5578);
    address public powerToken = 0xE06Af68F0c9e819513a6CD083EF6848E76C28CD8;

    Utilizer public utilizer;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 33_228_726);

        utilizer = new Utilizer(stakingAddress, powerToken);
    }

    function testExchangeView() public {
        address user = 0xf496eEeD857aA4709AC4D5B66b6711975623D355;
        uint256[] memory tokens = utilizer.exchangeView(array(user));
        assertEq(tokens[0], 1_552_311_773_095_364_910_258_616);
    }
}
