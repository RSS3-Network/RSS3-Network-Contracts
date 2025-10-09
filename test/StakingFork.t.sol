// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.24;

import {Chips} from "../src/Chips.sol";
import {Settlement} from "../src/Settlement.sol";
import {Staking} from "../src/Staking.sol";
import {Const} from "../src/libraries/Const.sol";
import {Node, UnstakeRequest} from "../src/libraries/DataTypes.sol";
import {CommonTest} from "./helpers/CommonTest.sol";
import {
    TransparentUpgradeableProxy as Proxy
} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IProxy {
    function upgradeTo(address) external;
}

contract StakingForkTest is CommonTest {
    address payable public stakingAddress = payable(0x28F14d917fddbA0c1f2923C406952478DfDA5578);
    address payable public settlementAddress = payable(0x0cE3159BF19F3C55B648D04E8f0Ae1Ae118D2A0B);
    address payable public chipsAddress = payable(0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE);

    address public constant proxyAdminOwner = 0x8AC80fa0993D95C9d6B8Cb494E561E6731038941;
    address public constant diygod = 0xC8b960D09C0078c18Dcbe7eB9AB9d816BcCa8944;

    Staking public staking;
    Settlement public settlement;
    Chips public chips;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 8_437_614);

        // deploy staking
        Staking stakingImpl = new Staking(address(1111), 22.5 days, 22.5 days, address(0xbbb));
        vm.prank(proxyAdminOwner);
        IProxy(stakingAddress).upgradeTo(address(stakingImpl));
        staking = Staking(stakingAddress);

        // deploy settlement
        Settlement settlementImpl_ = new Settlement(true);
        vm.prank(proxyAdminOwner);
        IProxy(settlementAddress).upgradeTo(address(settlementImpl_));
        settlement = Settlement(settlementAddress);

        // deploy chips
        Chips chipsImpl = new Chips();
        vm.prank(proxyAdminOwner);
        IProxy(chipsAddress).upgradeTo(address(chipsImpl));
        chips = Chips(chipsAddress);

        // initialize staking
        staking.initialize(address(0), address(0), address(0), false, true);
    }

    function testCreateNodeFork() public {
        address alice = address(0xaaaaaa);
        vm.prank(alice);
        staking.createNode("alice", "alice's node", uint64(1000), false);

        // check node
        Node memory node = staking.getNode(alice);
        assertEq(node.nodeId, 87);
        assertEq(node.taxRateBasisPoints, uint64(1000));
        assertEq(node.name, "alice");
        assertEq(node.description, "alice's node");
        assertEq(node.operationPoolTokens, uint256(0));
        assertEq(node.stakingPoolTokens, uint256(0));
        assertEq(node.totalShares, uint256(0));
        assertEq(node.publicGood, false);
        assertEq(node.alpha, false);
        assertEq(uint256(node.status), 0);
    }

    function testMergeChipsFork() public {
        uint256[] memory tokenIds =
            array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        assertEq(shares, Const.SHARES_PER_CHIP);
        assertEq(nodeAddr, address(0x08d66b34054a174841e2361bd4746Ff9F4905cC2));

        vm.prank(diygod);
        uint256 newChipId = staking.mergeChips(tokenIds);

        // check chip info
        (address nodeAddr2, uint256 tokens2, uint256 shares2) = staking.getChipInfo(newChipId);
        assertEq(nodeAddr, nodeAddr2);
        assertApproxEqAbs(tokens * 4, tokens2, 4); // 4 is the max diff
        assertApproxEqAbs(shares * 4, shares2, 4); // 4 is the max diff

        // check burned chips
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
        assertApproxEqAbs(req.unstakeAmount, tokens * 2, 2);

        // check node
        Node memory nodeAfter = staking.getNode(nodeAddr);
        assertApproxEqAbs(nodeAfter.totalShares, nodeBefore.totalShares - shares * 2, 2);
        assertApproxEqAbs(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 2, 2);
    }

    function testRequestUnstakeForkWithMerge() public {
        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens, uint256 shares) = staking.getChipInfo(1690);
        Node memory nodeBefore = staking.getNode(nodeAddr);

        uint256[] memory tokenIds =
            array(uint256(1690), uint256(1691), uint256(1693), uint256(1695));
        vm.prank(diygod);
        uint256 tokenId = staking.mergeChips(tokenIds);

        vm.prank(diygod);
        uint256 requestId = staking.requestUnstake(nodeAddr, array(tokenId));

        // check status
        UnstakeRequest memory req = staking.getPendingUnstake(requestId);
        assertEq(req.owner, diygod);
        assertEq(req.nodeAddr, nodeAddr);
        assertEq(req.timestamp, block.timestamp);
        assertApproxEqAbs(req.unstakeAmount, tokens * 4, 4);

        // check node
        Node memory nodeAfter = staking.getNode(nodeAddr);
        // 4 is the max diff
        assertApproxEqAbs(nodeAfter.totalShares, nodeBefore.totalShares - shares * 4, 4);
        assertApproxEqAbs(nodeAfter.stakingPoolTokens, nodeBefore.stakingPoolTokens - tokens * 4, 4);
    }

    // solhint-disable-next-line function-max-lines
    function testStakingStorageLayout() public view {
        assertEq(staking.chipsContract(), 0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE);
        assertEq(staking.isSettlementPhase(), false);
        assertEq(staking.isAlphaPhase(), false);

        (uint256 totalOpRewards, uint256 totalStRewards) = settlement.getBonusInfo();
        assertEq(totalOpRewards, 12_328_767_123_287_671_232_876);
        assertEq(totalStRewards, 49_315_068_493_150_684_931_506);

        // check node info
        // node 1
        Node memory node = staking.getNode(0x827431510a5D249cE4fdB7F00C83a3353F471848);
        _checkNode(
            0x827431510a5D249cE4fdB7F00C83a3353F471848,
            1,
            "Henry",
            "Henry's awesome Node",
            1000,
            uint256(13_681_924_472_668_548_186_301),
            uint256(148_691_318_047_894_295_870_052),
            uint256(112_081_880_869_482_220_448_282),
            false,
            true
        );
        // node 86
        node = staking.getNode(0xe2438b577bdD335B69ef4f94839d7Ac05bBFf02F);
        _checkNode(
            0xe2438b577bdD335B69ef4f94839d7Ac05bBFf02F,
            86,
            "21312",
            "asdasdsadadasdsa",
            0,
            uint256(0),
            0,
            0,
            true,
            true
        );

        // check node counter
        assertEq(staking.getNodeCount(), 86);

        // check _pendingWithdrawalCounter, slot 9
        assertEq(vm.load(address(staking), bytes32(uint256(9))), bytes32(uint256(0x11)));

        // check _pendingUnstakeCounter, slot 11
        assertEq(vm.load(address(staking), bytes32(uint256(11))), bytes32(uint256(0x84)));

        // check _demotionIdCounter, slot 26
        assertEq(vm.load(address(staking), bytes32(uint256(26))), bytes32(uint256(0x0)));

        // check public pool
        node = staking.getPublicPool();
        assertEq(node.nodeId, 0);
        assertEq(node.name, "Public Good Pool");
        assertEq(node.taxRateBasisPoints, uint64(1166));
        assertEq(node.operationPoolTokens, uint256(0));
        assertEq(node.stakingPoolTokens, uint256(115_295_369_728_917_494_863_411));
        assertEq(node.totalShares, uint256(107_537_638_591_157_899_782_190));
        assertEq(node.publicGood, true);
        assertEq(node.alpha, false);

        // check PAUSE_ROLE
        assertEq(staking.getRoleMemberCount(keccak256("PAUSE_ROLE")), 1);
        assertEq(
            staking.hasRole(keccak256("PAUSE_ROLE"), 0x7ef00577fAAa44D0491970D6516eB7b90EC3c80E),
            true
        );
        // check ORACLE_ROLE
        assertEq(staking.getRoleMemberCount(keccak256("ORACLE_ROLE")), 1);
        assertEq(staking.hasRole(keccak256("ORACLE_ROLE"), address(settlement)), true);

        // check pool info
        (
            uint256 totalOperationPoolTokens,
            uint256 totalStakingPoolTokens,
            uint256 totalSlashingPoolTokens
        ) = staking.getPoolInfo();
        assertEq(totalOperationPoolTokens, uint256(3_504_689_749_175_012_701_414_133));
        assertEq(totalStakingPoolTokens, uint256(123_802_676_919_381_578_897_049_899));
        assertEq(totalSlashingPoolTokens, uint256(0));

        // check chip info
        (address nodeAddr, uint256 tokens, uint256 shares) = staking.getChipInfo(1);
        assertEq(nodeAddr, 0x827431510a5D249cE4fdB7F00C83a3353F471848);
        assertEq(tokens, uint256(663_315_590_773_513_392_274));
        assertEq(shares, 500 ether);

        (nodeAddr, tokens, shares) = staking.getChipInfo(139_020);
        assertEq(nodeAddr, 0xc29f2Aec9dC8cdbC58da0bE1b9F612A629c83Ac5);
        assertEq(tokens, uint256(617_815_996_884_528_043_750));
        assertEq(shares, 500 ether);

        (nodeAddr, tokens, shares) = staking.getChipInfo(144_762);
        assertEq(nodeAddr, 0x69982E017Acc0FDE3d1542205089A8d3EAfcD1B7);
        assertEq(tokens, uint256(2_003_669_168_218_235_315_045_590));
        assertEq(shares, uint256(1_549_774_898_189_709_147_376_307));
    }

    /// @dev Should pay more attention if this test fails.
    function testCheckInitializer() public view {
        bytes32 initializerSlot = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;

        // check staking is initialized, should be 4 for next version
        assertEq(
            vm.load(address(staking), initializerSlot),
            bytes32(uint256(4)),
            "check staking initializer"
        );
        // check settlement, should be 4 for next version
        assertEq(
            vm.load(address(settlement), initializerSlot),
            bytes32(uint256(4)),
            "check settlement initializer"
        );
        // check chips, should be 2 for next version
        assertEq(
            vm.load(address(chips), initializerSlot), bytes32(uint256(2)), "check chips initializer"
        );
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
        Node memory node = staking.getNode(nodeAddr);
        assertEq(node.name, name);
        assertEq(node.description, description);
        assertEq(node.nodeId, nodeId);
        assertEq(node.taxRateBasisPoints, taxRateBasisPoints);
        assertEq(node.operationPoolTokens, operationPoolTokens);
        assertEq(node.stakingPoolTokens, stakingPoolTokens);
        assertEq(node.totalShares, totalShares);
        assertEq(node.publicGood, publicGood);
        assertEq(node.alpha, alpha);
    }
}
