// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {Const} from "../src/libraries/Const.sol";
import {Node, UnstakeRequest} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {TransparentUpgradeableProxy as Proxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy as IProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";

contract StakingForkTest is CommonTest {
    address public constant diygod = 0xC8b960D09C0078c18Dcbe7eB9AB9d816BcCa8944;
    address public constant chips = 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE;

    Staking public staking;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 6571169);

        Staking st = new Staking(address(1111), 1944000, 1944000, address(0xbbb));

        Proxy proxy = Proxy(payable(0x28F14d917fddbA0c1f2923C406952478DfDA5578));
        vm.prank(0x8AC80fa0993D95C9d6B8Cb494E561E6731038941);
        IProxy(address(proxy)).upgradeTo(address(st));

        staking = Staking(address(proxy));

        // reinitialize
        staking.initialize(address(0), address(0), address(0));
    }

    function testMergeChipsFork() public {
        uint256[] memory tokenIds = array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        assertEq(shares, Const.SHARES_PER_CHIP);
        assertEq(nodeAddr, address(0x08d66b34054a174841e2361bd4746Ff9F4905cC2));

        vm.prank(diygod);
        uint256 tokenId = staking.mergeChips(tokenIds);

        // check chip info
        (address nodeAddr2, uint256 tokens2, uint256 shares2) = staking.getChipInfo(tokenId);
        assertEq(nodeAddr, nodeAddr2);
        assertApproxEqAbs(tokens * 4, tokens2, 1);
        assertApproxEqAbs(shares * 4, shares2, 1);

        assertEq(IERC721(chips).ownerOf(tokenId), diygod);
    }

    function testStakeFork() public {
        uint256 amount = 500 ether;

        vm.prank(alice);
        staking.createNode("Alice", "Alice", _defaultTaxRateBasisPoints, false);

        vm.deal(bob, amount);
        vm.prank(bob);
        uint256 tokenId = staking.stake{value: amount}(alice);

        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(tokenId);
        assertEq(nodeAddr, alice);
        assertEq(tokens, amount);
        assertEq(shares, amount);

        assertEq(IERC721(chips).ownerOf(tokenId), bob);
    }

    function testRequestUnstakeFork() public {
        vm.prank(0x7ef00577fAAa44D0491970D6516eB7b90EC3c80E);
        staking.disableAlphaPhase();

        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        assertEq(shares, Const.SHARES_PER_CHIP);
        assertTrue(tokens > shares);
        Node memory nodeBefore = staking.getNode(nodeAddr);

        vm.prank(diygod);
        uint256 requestId = staking.requestUnstake(nodeAddr, array(uint256(1690), uint256(1691)));

        // check status
        UnstakeRequest memory req = staking.getPendingUnstake(requestId);
        assertEq(req.owner, diygod);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, tokens * 2);

        // check node
        Node memory nodeAfter = staking.getNode(nodeAddr);
        assertEq(nodeAfter.totalShares, nodeBefore.totalShares - shares * 2);
        assertEq(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 2);
    }

    function testRequestUnstakeForkWithMerge() public {
        vm.prank(0x7ef00577fAAa44D0491970D6516eB7b90EC3c80E);
        staking.disableAlphaPhase();

        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        Node memory nodeBefore = staking.getNode(nodeAddr);

        uint256[] memory tokenIds = array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        vm.prank(diygod);
        uint256 tokenId = staking.mergeChips(tokenIds);

        vm.prank(diygod);
        uint256 requestId = staking.requestUnstake(nodeAddr, array(tokenId));

        // check status
        UnstakeRequest memory req = staking.getPendingUnstake(requestId);
        assertEq(req.owner, diygod);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertApproxEqAbs(req.unstakeAmount, tokens * 4, 1);

        // check node
        Node memory nodeAfter = staking.getNode(nodeAddr);
        assertApproxEqAbs(nodeAfter.totalShares, nodeBefore.totalShares - shares * 4, 1);
        assertApproxEqAbs(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 4, 1);
    }

    // solhint-disable-next-line function-max-lines
    function testStakingStorageLayout() public view {
        assertEq(staking.chipsContract(), 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE);
        assertEq(staking.isSettlementPhase(), false);
        assertEq(staking.isAlphaPhase(), true);
        // check node info
        // node 1
        Node memory node = staking.getNode(0x827431510a5D249cE4fdB7F00C83a3353F471848);
        assertEq(node.nodeId, 1);
        assertEq(node.taxRateBasisPoints, uint64(1000));
        assertEq(node.name, "Henry");
        assertEq(node.description, "Henry's awesome Node");
        assertEq(node.operationPoolTokens, uint256(13098345260616808484943));
        assertEq(node.stakingPoolTokens, uint256(191354444561962829822546));
        assertEq(node.totalShares, uint256(148500000000000000000000));
        assertEq(node.publicGood, false);
        assertEq(node.alpha, true);
        assertEq(node.registerTime, 0);
        assertEq(node.offlineTime, 0);
        assertEq(node.slashedTime, 0);
        assertEq(uint256(node.status), 0);

        // node 72
        node = staking.getNode(0x5cccbC2DF34c103e3a198625C0a3bc1182d69BBe);
        assertEq(node.nodeId, 72);
        assertEq(node.taxRateBasisPoints, 0);
        assertEq(node.name, "Google Cloud");
        assertEq(node.description, "Google Cloud RSS3 Public Good Node");
        assertEq(node.operationPoolTokens, uint256(0));
        assertEq(node.stakingPoolTokens, uint256(0));
        assertEq(node.totalShares, 0);
        assertEq(node.publicGood, true);
        assertEq(node.alpha, true);
        assertEq(node.registerTime, 0);
        assertEq(node.offlineTime, 0);
        assertEq(node.slashedTime, 0);
        assertEq(uint256(node.status), 0);

        // node 83
        node = staking.getNode(0xCe56132aB93bfA39241Ad844433b58e926295186);
        assertEq(node.nodeId, 83);
        assertEq(node.taxRateBasisPoints, uint64(600));
        assertEq(node.name, "Money Tree RSS3");
        assertEq(node.operationPoolTokens, uint256(10357200000000000000000));
        assertEq(node.stakingPoolTokens, uint256(0));
        assertEq(node.totalShares, 0);
        assertEq(node.publicGood, false);
        assertEq(node.alpha, true);
        assertEq(node.registerTime, 0);
        assertEq(node.offlineTime, 0);
        assertEq(node.slashedTime, 0);
        assertEq(uint256(node.status), 0);

        // check node counter
        assertEq(staking.getNodeCount(), 83);

        // check _pendingWithdrawalCounter, slot 9
        assertEq(vm.load(address(staking), bytes32(uint256(9))), 0);

        // check _pendingUnstakeCounter, slot 11
        assertEq(vm.load(address(staking), bytes32(uint256(11))), 0);

        // check public pool
        node = staking.getPublicPool();
        assertEq(node.nodeId, 0);
        assertEq(node.taxRateBasisPoints, uint64(1168));
        assertEq(node.name, "Public Good Pool");
        assertEq(node.operationPoolTokens, uint256(0));
        assertEq(node.stakingPoolTokens, uint256(104194643234036416044119));
        assertEq(node.totalShares, uint256(100000000000000000000000));
        assertEq(node.publicGood, true);
        assertEq(node.alpha, false);
        assertEq(node.registerTime, 0);
        assertEq(node.offlineTime, 0);
        assertEq(node.slashedTime, 0);
        assertEq(uint256(node.status), 0);

        // check pool info
        (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens, uint256 totalSlashingPoolTokens) = staking
            .getPoolInfo();
        assertEq(totalOperationPoolTokens, uint256(3546654536250790710758117));
        assertEq(totalStakingPoolTokens, uint256(93773491338396834893836628));
        assertEq(totalSlashingPoolTokens, uint256(0));

        // check chip info
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1);
        assertEq(nodeAddr, 0x827431510a5D249cE4fdB7F00C83a3353F471848);
        assertEq(tokens, uint256(644291059131187979200));
        assertEq(shares, 500 ether);

        (nodeAddr, tokens, shares) = staking.getChipInfo(139020);
        assertEq(nodeAddr, 0xc29f2Aec9dC8cdbC58da0bE1b9F612A629c83Ac5);
        assertEq(tokens, uint256(599127317100828251171));
        assertEq(shares, 500 ether);

        (nodeAddr, tokens, shares) = staking.getChipInfo(144587);
        assertEq(nodeAddr, 0x69982E017Acc0FDE3d1542205089A8d3EAfcD1B7);
        assertEq(tokens, uint256(606238427225428543923));
        assertEq(shares, uint256(483064298787126186988));

        (nodeAddr, tokens, shares) = staking.getChipInfo(144591);
        assertEq(nodeAddr, 0x69982E017Acc0FDE3d1542205089A8d3EAfcD1B7);
        assertEq(tokens, uint256(10063076087164542382773));
        assertEq(shares, uint256(8018483447074598157297));
    }
}
