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
        _rss3.transfer(carol, 100000 ether);
        _rss3.transfer(dave, 100000 ether);

        // transfer tokens to settlement contract
        _rss3.transfer(address(_settlement), 30000000 ether);
    }

    function testCheckSetupStatus() public {
        assertEq(_settlement.stakingContract(), address(_staking));
        assertEq(_settlement.currentEpoch(), 1);
        assertEq(_settlement.EPOCH_DURATION(), 18 hours);
        assertEq(_settlement.TOTAL_REWARDS_PER_YEAR(), 30000000 ether);
    }

    function testDistributeRewards() public {
        _createNode(alice);
        _createNode(bob);

        (uint256 requestBonusPerEpoch, uint256 stakingRewardPerEpoch) = _settlement.getBonusInfo();

        expectEmit();
        emit Transfer(address(_settlement), address(_staking), requestBonusPerEpoch + stakingRewardPerEpoch);
        vm.prank(oracleAccount);
        _settlement.distributeRewards(
            array(alice, bob), // node addresses
            array(1 ether, 2 ether), // request fees
            array(100, 300) // request counts
        );

        // TODO: check status
    }

    function testStakingRewards(uint256 stakingAmount) public {
        vm.assume(stakingAmount > 5000 && stakingAmount < 10000);
        stakingAmount = stakingAmount * 1 ether;

        _createNode(alice);
        _createNode(bob);
        _createPublicGoodNode(carol);

        vm.startPrank(alice);
        _rss3.approve(address(_staking), stakingAmount);
        _staking.stakeToPublicPool(carol, stakingAmount);
        vm.stopPrank();

        vm.startPrank(bob);
        _rss3.approve(address(_staking), 10000 ether);
        _staking.stake(alice, 10000 ether);
        vm.stopPrank();

        vm.startPrank(carol);
        _rss3.approve(address(_staking), 8000 ether);
        _staking.stake(alice, 8000 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        _rss3.approve(address(_staking), stakingAmount);
        _staking.stake(bob, stakingAmount);
        vm.stopPrank();

        vm.startPrank(carol);
        _rss3.approve(address(_staking), 9000 ether);
        _staking.stake(bob, 9000 ether);
        vm.stopPrank();

        address[] memory nodeAddrs = array(alice, bob);
        (uint256 publicPoolReward, uint256[] memory nodeRewards) = _internalSettlementTest.getStakingRewards(nodeAddrs);

        uint256 sum = publicPoolReward;
        for (uint256 i = 0; i < nodeRewards.length; i++) {
            sum += nodeRewards[i];
        }

        //  we use `nodeRewards.length` here because each node's reward may have the 1wei roundup caused by truncation
        assert(
            sum <= _internalSettlementTest.getTotalStakingRewardsPerEpoch() &&
                sum >= _internalSettlementTest.getTotalStakingRewardsPerEpoch() - nodeRewards.length
        );
    }
}
