// SPDX-License-Identifier: MIT
// solhint-disable comprehensive-interface,no-console
pragma solidity 0.8.20;

//import {console2 as console} from "forge-std/console2.sol";
import {CommonTest} from "test/helpers/CommonTest.sol";

contract SettlementTest is CommonTest {
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        _setUp();

        // transfer tokens
        _rss3.transfer(alice, 100000 ether);
        _rss3.transfer(bob, 100000 ether);
        _rss3.transfer(address(0xccc), 100000 ether);
        _rss3.transfer(address(0xddd), 100000 ether);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
    }

    function testDistributeRewards() public {
        _createNode(alice);

        address[] memory nodeAddrs = new address[](1);
        nodeAddrs[0] = alice;

        uint256[] memory requestFees = new uint256[](1);
        requestFees[0] = 1 ether;

        uint256[] memory requestBonuses = new uint256[](1);
        requestBonuses[0] = 1 ether;

        uint256[] memory stakingRewards = new uint256[](1);
        stakingRewards[0] = 1 ether;

        uint256[] memory requestCounts = new uint256[](1);
        stakingRewards[0] = 100;

        (uint256 requestBonusPerEpoch, uint256 stakingRewardPerEpoch) = _settlement.getBonusInfo();

        vm.startPrank(oracleAccount);

        expectEmit();
        emit Transfer(address(_settlement), address(_staking), requestBonusPerEpoch + stakingRewardPerEpoch);
        _settlement.distributeRewards(nodeAddrs, requestFees, requestCounts);
        vm.stopPrank();
    }

    function testStakingRewards(uint256 stakingAmount) public {
        _createNode(alice);
        _createNode(bob);

        vm.startPrank(alice);

        vm.assume(stakingAmount > 5000 && stakingAmount < 10000);
        stakingAmount = stakingAmount * 1 ether;

        _rss3.approve(address(_staking), stakingAmount);
        _staking.stakeToPublicPool(stakingAmount, alice);
        vm.stopPrank();

        vm.startPrank(bob);
        _rss3.approve(address(_staking), 10000 ether);
        _staking.stake(alice, 10000 ether);
        vm.stopPrank();

        vm.startPrank(address(0xccc));
        _rss3.approve(address(_staking), 8000 ether);
        _staking.stake(alice, 8000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        _rss3.approve(address(_staking), stakingAmount);
        _staking.stake(bob, stakingAmount);
        vm.stopPrank();

        vm.startPrank(address(0xccc));
        _rss3.approve(address(_staking), 9000 ether);
        _staking.stake(bob, 9000 ether);
        vm.stopPrank();

        address[] memory nodeAddrs = new address[](2);
        nodeAddrs[0] = alice;
        nodeAddrs[1] = bob;

        (uint256 publicPoolReward, uint256[] memory nodeRewards) = _internalSettlementTest.getStakingRewards(nodeAddrs);

        uint256 sum = publicPoolReward;
        for (uint256 i = 0; i < nodeRewards.length; i++) {
            sum += nodeRewards[i];
        }

        assert(
            sum <= _internalSettlementTest.getTotalStakingRewardsPerEpoch() &&
                sum >= _internalSettlementTest.getTotalStakingRewardsPerEpoch() - nodeRewards.length
        );
    }
}
