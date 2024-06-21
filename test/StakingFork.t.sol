// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {CommonTest} from "test/helpers/CommonTest.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {TransparentUpgradeableProxy as Proxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy as IProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";

contract StakingForkTest is CommonTest {
    address public constant diygod = 0xC8b960D09C0078c18Dcbe7eB9AB9d816BcCa8944;

    Staking public staking;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 4515437);

        Staking st = new Staking(address(1111), 25, 1944000, 1944000, 200, 100, 10000000000000000000000, 500);

        Proxy proxy = Proxy(payable(0x28F14d917fddbA0c1f2923C406952478DfDA5578));
        vm.prank(0x8AC80fa0993D95C9d6B8Cb494E561E6731038941);
        IProxy(address(proxy)).upgradeTo(address(st));

        staking = Staking(address(proxy));
    }

    function testMergeChipsFork() public {
        uint256[] memory tokenIds = array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        assertEq(shares, staking.SHARES_PER_CHIP());
        assertEq(nodeAddr, address(0x08d66b34054a174841e2361bd4746Ff9F4905cC2));

        vm.prank(diygod);
        uint256 tokenId = staking.mergeChips(tokenIds);
        (address nodeAddr2, uint256 tokens2, uint256 shares2) = staking.getChipInfo(tokenId);
        assertEq(nodeAddr, nodeAddr2);
        assertEq(tokens * 4, tokens2);
        assertEq(shares * 4, shares2);
    }

    function testStakeFork() public {
        uint256 amount = 100 ether;

        vm.prank(alice);
        staking.createNode("Alice", "Alice", _defaultTaxRateBasisPoints, false);

        vm.deal(bob, amount);
        vm.prank(bob);
        uint256 tokenId = staking.stake{value: amount}(alice);

        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(tokenId);
        assertEq(nodeAddr, alice);
        assertEq(tokens, amount);
        assertEq(shares, amount);
    }

    function testRequestUnstakeFork() public {
        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        DataTypes.Node memory nodeBefore = staking.getNode(nodeAddr);

        uint256[] memory tokenIds = array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        vm.prank(diygod);
        uint256 tokenId = staking.mergeChips(tokenIds);

        vm.prank(0x7ef00577fAAa44D0491970D6516eB7b90EC3c80E);
        staking.disableAlphaPhase();

        vm.prank(diygod);
        uint256 requestId = staking.requestUnstake(nodeAddr, array(tokenId));

        // check status
        DataTypes.UnstakeRequest memory req = staking.getPendingUnstake(requestId);
        assertEq(req.owner, diygod);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, tokens * 4);

        // check node
        DataTypes.Node memory nodeAfter = staking.getNode(nodeAddr);
        assertEq(nodeAfter.totalShares, nodeBefore.totalShares - shares * 4);
        assertEq(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 4);
    }
}
