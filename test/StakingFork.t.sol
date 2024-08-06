// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";
import {Const} from "../src/libraries/Const.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {TransparentUpgradeableProxy as Proxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy as IProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";

contract StakingForkTest is CommonTest {
    address public constant diygod = 0xC8b960D09C0078c18Dcbe7eB9AB9d816BcCa8944;
    address public constant chips = 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE;

    Staking public staking;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 5787906);

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
        assertEq(tokens * 4, tokens2);
        assertEq(shares * 4, shares2);

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
        DataTypes.Node memory nodeBefore = staking.getNode(nodeAddr);

        vm.prank(diygod);
        uint256 requestId = staking.requestUnstake(nodeAddr, array(uint256(1690), uint256(1691)));

        // check status
        DataTypes.UnstakeRequest memory req = staking.getPendingUnstake(requestId);
        assertEq(req.owner, diygod);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertEq(req.unstakeAmount, tokens * 2);

        // check node
        DataTypes.Node memory nodeAfter = staking.getNode(nodeAddr);
        assertEq(nodeAfter.totalShares, nodeBefore.totalShares - shares * 2);
        assertEq(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 2);
    }

    function testRequestUnstakeForkWithMerge() public {
        vm.prank(0x7ef00577fAAa44D0491970D6516eB7b90EC3c80E);
        staking.disableAlphaPhase();

        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        DataTypes.Node memory nodeBefore = staking.getNode(nodeAddr);

        uint256[] memory tokenIds = array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        vm.prank(diygod);
        uint256 tokenId = staking.mergeChips(tokenIds);

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

    // solhint-disable-next-line function-max-lines
    function testStakingStorageLayout() public view {
        assertEq(staking.chipsContract(), 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE);
        assertEq(staking.isSettlementPhase(), false);
        assertEq(staking.isAlphaPhase(), true);
        // check node info
        // node 1
        DataTypes.Node memory node = staking.getNode(0x827431510a5D249cE4fdB7F00C83a3353F471848);
        _checkNode(
            0x827431510a5D249cE4fdB7F00C83a3353F471848,
            1,
            "Henry",
            "Henry's awesome Node",
            1000,
            uint256(12793157235268997410007),
            uint256(188607752333832530148001),
            uint256(148500000000000000000000),
            false,
            true
        );
        // node 83
        node = staking.getNode(0x827431510a5D249cE4fdB7F00C83a3353F471848);
        _checkNode(
            0xCe56132aB93bfA39241Ad844433b58e926295186,
            83,
            "Money Tree RSS3",
            "Those who stay here are full of luck\n",
            600,
            uint256(10357200000000000000000),
            0,
            0,
            false,
            true
        );

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
        assertEq(node.stakingPoolTokens, uint256(102726750648321495462628));
        assertEq(node.totalShares, uint256(100000000000000000000000));
        assertEq(node.publicGood, true);
        assertEq(node.alpha, false);

        // check pool info
        (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens, uint256 totalSlashingPoolTokens) = staking
            .getPoolInfo();
        assertEq(totalOperationPoolTokens, uint256(3430942886901868893005511));
        assertEq(totalStakingPoolTokens, uint256(88666655712935490505541127));
        assertEq(totalSlashingPoolTokens, uint256(0));

        // check chip info
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1);
        assertEq(nodeAddr, 0x827431510a5D249cE4fdB7F00C83a3353F471848);
        assertEq(tokens, uint256(635042937150951279959));
        assertEq(shares, 500 ether);

        (nodeAddr, tokens, shares) = staking.getChipInfo(139020);
        assertEq(nodeAddr, 0xc29f2Aec9dC8cdbC58da0bE1b9F612A629c83Ac5);
        assertEq(tokens, uint256(590053490751951480978));
        assertEq(shares, 500 ether);
    }

    function _checkNode(
        address nodeAddr,
        uint256 nodeId,
        string memory name,
        string memory description,
        uint64 taxRateBasisPoints,
        uint256 operationPoolTokens,
        uint256 stakingPoolTokens,
        uint256 totalShares,
        bool publicGood,
        bool alpha
    ) internal view {
        DataTypes.Node memory node = staking.getNode(nodeAddr);
        assertEq(node.nodeId, nodeId);
        assertEq(node.account, nodeAddr);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.publicGood, publicGood);
        assertEq(node.alpha, alpha);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.stakingPoolTokens, stakingPoolTokens);
        assertEq(node.totalShares, totalShares);
        assertEq(node.registerTime, 0);
        assertEq(node.offlineTime, 0);
        assertEq(node.slashedTime, 0);
        assertEq(uint256(node.status), 0);
    }
}
