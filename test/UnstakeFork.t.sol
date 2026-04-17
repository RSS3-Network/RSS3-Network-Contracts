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

contract StakingForkTest is CommonTest {
    address payable public stakingAddress = payable(0x28F14d917fddbA0c1f2923C406952478DfDA5578);
    address payable public chipsAddress = payable(0x849f8F55078dCc69dD857b58Cc04631EBA54E4DE);

    address public constant proxyAdminOwner = 0x8AC80fa0993D95C9d6B8Cb494E561E6731038941;
    address public constant diygod = 0xC8b960D09C0078c18Dcbe7eB9AB9d816BcCa8944;

    Staking public staking;
    Utilizer public utilizer;

    function setUp() public {
        vm.createSelectFork("https://rpc.rss3.io", 33_228_726);

        // deploy staking
        Staking stakingImpl = new Staking(address(1111), 0, 0, address(0xbbb));
        vm.prank(proxyAdminOwner);
        IProxy(stakingAddress).upgradeTo(address(stakingImpl));
        staking = Staking(stakingAddress);

        utilizer = new Utilizer(address(staking), address(0xbbb));
    }

    function testUnstakeFork() public {
        address nodeAddr = 0x08d66b34054a174841e2361bd4746Ff9F4905cC2;
        (, uint256 tokens1, uint256 shares1) = staking.getChipInfo(1690);
        (, uint256 tokens2, uint256 shares2) = staking.getChipInfo(1691);
        assertTrue(tokens1 > shares1);
        assertTrue(tokens2 > shares2);

        address owner = IERC721(chipsAddress).ownerOf(1690);

        Node memory nodeBefore = staking.getNode(nodeAddr);
        uint256 balanceBefore = owner.balance;

        utilizer.unstake(array(uint256(1690), uint256(1691)));

        // check status
        uint256 balanceAfter = owner.balance;
        assertEq(balanceAfter, balanceBefore + tokens1 + tokens2);

        // check node
        Node memory nodeAfter = staking.getNode(nodeAddr);
        assertApproxEqAbs(
            nodeAfter.totalShares, nodeBefore.totalShares - shares1 - shares2, 2, "totalShares"
        );
        assertApproxEqAbs(
            nodeAfter.stakingPoolTokens,
            nodeBefore.stakingPoolTokens - tokens1 - tokens2,
            2,
            "stakingPoolTokens"
        );
        assertEq(
            nodeAfter.operationPoolTokens, nodeBefore.operationPoolTokens, "operationPoolTokens"
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
