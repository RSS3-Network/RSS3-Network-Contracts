// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

import {CommonTest} from "test/helpers/CommonTest.sol";
import {DataTypes} from "../src/libraries/DataTypes.sol";
import {Staking} from "../src/Staking.sol";
import {Settlement} from "../src/Settlement.sol";
import {TransparentUpgradeableProxy as Proxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";
import {ITransparentUpgradeableProxy as IProxy} from "../src/upgradeability/TransparentUpgradeableProxy.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract StakingForkTest is CommonTest {
    address public constant diygod = 0xC8b960D09C0078c18Dcbe7eB9AB9d816BcCa8944;
    address public constant chips = 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE;

    Staking public staking;
    Settlement public settlement;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 7540074);

        // deploy staking
        Staking st = new Staking(
            address(1111),
            25,
            1944000,
            1944000,
            200,
            100,
            10000000000000000000000,
            500,
            address(0xbbb)
        );
        Proxy stakingProxy = Proxy(payable(0x28F14d917fddbA0c1f2923C406952478DfDA5578));
        vm.prank(0x8AC80fa0993D95C9d6B8Cb494E561E6731038941);
        IProxy(address(stakingProxy)).upgradeTo(address(st));
        staking = Staking(address(stakingProxy));

        // deploy settlement
        Settlement settlement_ = new Settlement(true);
        Proxy settlementProxy = Proxy(payable(0x0cE3159BF19F3C55B648D04E8f0Ae1Ae118D2A0B));
        vm.prank(0x8AC80fa0993D95C9d6B8Cb494E561E6731038941);
        IProxy(address(settlementProxy)).upgradeTo(address(settlement_));
        settlement = Settlement(payable(address(settlementProxy)));
    }

    function testMergeChipsFork() public {
        uint256[] memory tokenIds = array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        assertEq(shares, staking.SHARES_PER_CHIP());
        assertEq(nodeAddr, address(0x08d66b34054a174841e2361bd4746Ff9F4905cC2));

        vm.prank(diygod);
        uint256 newChipId = staking.mergeChips(tokenIds);

        // check chip info

        (address nodeAddr2, uint256 tokens2, uint256 shares2) = staking.getChipInfo(newChipId);
        assertEq(nodeAddr, nodeAddr2);
        assertApproxEqAbs(tokens * 4, tokens2, 4); // 4 is the max diff
        assertApproxEqAbs(shares * 4, shares2, 4); // 4 is the max diff

        //         check burned chips
        for (uint256 i = 0; i < tokenIds.length; i++) {
            (nodeAddr, tokens, shares) = staking.getChipInfo(tokenIds[i]);
            assertEq(nodeAddr, address(0));
            assertEq(tokens, 0);
            assertEq(shares, 0);
        }
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
        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        assertEq(shares, staking.SHARES_PER_CHIP());
        assertTrue(tokens > shares);
        DataTypes.Node memory nodeBefore = staking.getNode(nodeAddr);

        vm.prank(diygod);
        uint256 requestId = staking.requestUnstake(nodeAddr, array(uint256(1690), uint256(1691)));

        // check status
        DataTypes.UnstakeRequest memory req = staking.getPendingUnstake(requestId);
        assertEq(req.owner, diygod);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertApproxEqAbs(req.unstakeAmount, tokens * 2, 2);

        // check node
        DataTypes.Node memory nodeAfter = staking.getNode(nodeAddr);
        assertApproxEqAbs(nodeAfter.totalShares, nodeBefore.totalShares - shares * 2, 2);
        assertApproxEqAbs(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 2, 2);
    }

    function testRequestUnstakeForkWithMerge() public {
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
        assertApproxEqAbs(req.unstakeAmount, tokens * 4, 4);

        // check node
        DataTypes.Node memory nodeAfter = staking.getNode(nodeAddr);
        // 4 is the max diff
        assertApproxEqAbs(nodeAfter.totalShares, nodeBefore.totalShares - shares * 4, 4);
        assertApproxEqAbs(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 4, 4);
    }

    function testStakingStorageLayout() public {
        assertEq(staking.chipsContract(), 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE);
        assertEq(staking.isSettlementPhase(), false);
        assertEq(staking.isAlphaPhase(), false);

        (uint256 totalOpRewards, uint256 totalStRewards) = settlement.getBonusInfo();
        assertEq(totalOpRewards, 12328767123287671232876);
        assertEq(totalStRewards, 49315068493150684931506);

        // check node info
        // node 1
        DataTypes.Node memory node = staking.getNode(0x827431510a5D249cE4fdB7F00C83a3353F471848);
        _checkNode(
            0x827431510a5D249cE4fdB7F00C83a3353F471848,
            1,
            "Henry",
            "Henry's awesome Node",
            1000,
            uint256(13469524266418053824302),
            uint256(170204797962892815044839),
            uint256(129860104969232393500215),
            false,
            true,
            false
        );
        // node 83
        node = staking.getNode(0xCe56132aB93bfA39241Ad844433b58e926295186);
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
            true,
            false
        );

        // check node counter
        assertEq(staking.getNodeCount(), 86);

        // check _pendingWithdrawalCounter, slot 9
        assertEq(vm.load(address(staking), bytes32(uint256(9))), bytes32(uint256(1)));

        // check _pendingUnstakeCounter, slot 11
        assertEq(vm.load(address(staking), bytes32(uint256(11))), bytes32(uint256(11)));

        // check public pool
        node = staking.getPublicPool();
        assertEq(node.nodeId, 0);
        assertEq(node.taxRateBasisPoints, uint64(1166));
        assertEq(node.operationPoolTokens, uint256(0));
        assertEq(node.stakingPoolTokens, uint256(105947834373481785005022));
        assertEq(node.totalShares, uint256(100000000000000000000000));
        assertEq(node.publicGood, false);
        assertEq(node.alpha, false);

        // check pool info
        (uint256 totalOperationPoolTokens, uint256 totalStakingPoolTokens, uint256 totalSlashingPoolTokens) = staking
            .getPoolInfo();
        assertEq(totalOperationPoolTokens, uint256(3676223372159389130580222));
        assertEq(totalStakingPoolTokens, uint256(99576088009465491532574685));
        assertEq(totalSlashingPoolTokens, uint256(0));

        // check chip info
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1);
        assertEq(nodeAddr, 0x827431510a5D249cE4fdB7F00C83a3353F471848);
        assertEq(tokens, uint256(655339058917360507379));
        assertEq(shares, 500 ether);

        (nodeAddr, tokens, shares) = staking.getChipInfo(139020);
        assertEq(nodeAddr, 0xc29f2Aec9dC8cdbC58da0bE1b9F612A629c83Ac5);
        assertEq(tokens, uint256(609976588619424481212));
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
        bool alpha,
        bool slashStatus
    ) internal {
        DataTypes.Node memory node = staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.nodeId, nodeId);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.stakingPoolTokens, stakingPoolTokens);
        assertEq(node.totalShares, totalShares);
        assertEq(node.publicGood, publicGood);
        assertEq(node.alpha, alpha);
        assertEq(node.slashStatus, slashStatus);
    }
}
