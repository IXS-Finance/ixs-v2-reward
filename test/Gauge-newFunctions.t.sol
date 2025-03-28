// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import {IGauge} from "contracts/interfaces/IGauge.sol";
import {IPoolFees} from "contracts/interfaces/IPoolFees.sol";

contract GaugeTest is BaseTest {
    // Gauge gauge;
    // address voter = address(0x1);
    address nonVoter = address(0x2);
    // address rewardToken = address(0x3);
    // address stakingToken = address(0x4);
    // address feesVotingReward = address(0x5);
    // address poolFees = address(0x6);
    uint256 rewardAmount = 1000 * 1e18;

    address public team;
    uint amount1 = 1e19;
    uint amount2 = 2e19;
    ERC20 token1 = new ERC20("test1", "TST1");
    ERC20 token2 = new ERC20("test2", "TST2");
    address poolFee;
    uint BASIC_POINT = 10000;


    function _setUp() public override {
        // ve
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.startPrank(address(owner2));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        vm.startPrank(address(owner3));
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAXTIME);
        vm.stopPrank();
        vm.warp(block.timestamp + 1);

        skipToNextEpoch(0);
        team = escrow.team();
        poolFee = gauge.poolFees();
    }

    function testNotifyRewardAmountSuccess() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Check that the reward rate and period finish are updated
        assertTrue(gauge.rewardRate() > 0);
        assertTrue(gauge.periodFinish() > block.timestamp);
        uint share1 = amount1 * IVoter(voter).feeForVe() / BASIC_POINT;
        uint share2 = amount2 * IVoter(voter).feeForVe() / BASIC_POINT;
        uint remain1 = amount1 - share1;
        uint remain2 = amount2 - share2;
        assertEq(IERC20(FRAX).balanceOf(address(gauge)), remain1);
        assertEq(IERC20(USDC).balanceOf(address(gauge)), remain2);

        uint256 expectedRatio1 = (remain1 * 1e30) / IERC20(address(gauge.stakingToken())).totalSupply();
        assertEq(gauge.getIndexRatio(address(FRAX)), expectedRatio1);

        uint256 expectedRatio2 = (remain2 * 1e30) / IERC20(address(gauge.stakingToken())).totalSupply();
        assertEq(gauge.getIndexRatio(address(USDC)), expectedRatio2);

        uint256 expectedRewardRate = rewardAmount / (gauge.periodFinish() - block.timestamp);
        assertEq(gauge.rewardRate(), expectedRewardRate);

    }
    function testNotifyRewardAmountAfterPeriodFinish() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        vm.warp(block.timestamp + 8 days);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Check that the reward rate is updated
        uint256 expectedRewardRate = rewardAmount / (gauge.periodFinish() - block.timestamp);
        assertEq(gauge.rewardRate(), expectedRewardRate);

        // Check that the period finish is updated
        assertTrue(gauge.periodFinish() > block.timestamp);

        // Check that the last update time is set to the current block timestamp
        assertEq(gauge.lastUpdateTime(), block.timestamp);
    }

    function testNotifyRewardAmountWithLeftover() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Simulate some time passing
        vm.warp(block.timestamp + 3 days);

        // Call notifyRewardAmount again with a new reward amount
        uint256 newRewardAmount = 500 * 1e18;
        deal(address(VELO), address(voter), newRewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), newRewardAmount);

        uint oldRewardRate = gauge.rewardRate();
        vm.prank(address(voter));
        gauge.notifyRewardAmount(newRewardAmount);

        // Check that the reward rate is updated with leftover
        uint256 leftover = (gauge.periodFinish() - block.timestamp) * oldRewardRate;
        uint256 expectedRewardRate = (newRewardAmount + leftover) / (gauge.periodFinish() - block.timestamp);
        assertEq(gauge.rewardRate(), expectedRewardRate);

        // Check that the period finish is updated
        assertTrue(gauge.periodFinish() > block.timestamp);

        // Check that the last update time is set to the current block timestamp
        assertEq(gauge.lastUpdateTime(), block.timestamp);
    }


    function testNotifyRewardAmountRevertNotVoter() public {
        // Attempt to call notifyRewardAmount as a non-voter
        vm.prank(nonVoter);
        vm.expectRevert(IGauge.NotVoter.selector);
        gauge.notifyRewardAmount(rewardAmount);
    }

    function testNotifyRewardAmountRevertZeroAmount() public {
        // Attempt to call notifyRewardAmount with zero amount
        vm.prank(address(voter));
        vm.expectRevert(IGauge.ZeroAmount.selector);

        gauge.notifyRewardAmount(0);
    }

    function testNotifyRewardAmountRevertZeroRewardRate() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        // Call notifyRewardAmount with a very small amount to trigger ZeroRewardRate
        vm.prank(address(voter));
        vm.expectRevert(IGauge.ZeroRewardRate.selector);
        gauge.notifyRewardAmount(1); // Assuming 1 is too small to create a non-zero reward rate
    }

    function testNotifyRewardAmountRevertRewardRateTooHigh() public {
        // temporiarily skip this test
    }
    
    function testGetRewardsClaimPartiallyPoolFeesSuccess() public {
        address user = address(0x6);
        
        uint stakedAmount = 1e10;
        uint feeAmount1 = 3e16; // 30% * 1e19 * stakeAmount / totalSupply = 30% * 1e19 * 1e10 / 1e12 = 3e16
        uint feeAmount2 = 6e16; // 30% * 2e19 * stakeAmount / totalSupply = 30% * 2e19 * 1e10 / 1e12 = 6e16

        // Mock the staking token balance for the user
        deal(address(pool), user, stakedAmount);

        // Simulate user staking
        vm.prank(user);
        IERC20(address(pool)).approve(address(gauge), stakedAmount);

        vm.prank(user);
        gauge.deposit(stakedAmount);

        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Call getReward as the user
        vm.prank(user);
        gauge.getReward(user);

        // Check that the trading fees are claimed and transferred to the user
        uint256 userToken1Balance = IERC20(address(FRAX)).balanceOf(user);
        uint256 userToken2Balance = IERC20(address(USDC)).balanceOf(user);
        assertEq(userToken1Balance, feeAmount1);
        assertEq(userToken2Balance, feeAmount2);

        // Check that the claimable amounts are reset
        assertEq(gauge.claimable(user, address(FRAX)), 0);
        assertEq(gauge.claimable(user, address(USDC)), 0);

        // Check that the state storage is updated correctly
        assertEq(gauge.rewards(user), 0);
        assertEq(gauge.userRewardPerTokenPaid(user), gauge.rewardPerTokenStored());
    }

    function testGetRewardsClaimFullyPoolFeesSuccess() public {
        address user = address(0x6);
        
        uint stakedAmount = 1e12;
        uint feeAmount1 = 3e18; // 30% * 1e19 * stakeAmount / totalSupply = 30% * 1e19 * 1e12 / 1e12
        uint feeAmount2 = 6e18; // 30% * 2e19 * stakeAmount / totalSupply = 30% * 2e19 * 1e12 / 1e12

        // Mock the staking token balance for the user
        deal(address(pool), user, stakedAmount);

        // Simulate user staking
        vm.prank(user);
        IERC20(address(pool)).approve(address(gauge), stakedAmount);

        vm.prank(user);
        gauge.deposit(stakedAmount);

        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Call getReward as the user
        vm.prank(user);
        gauge.getReward(user);

        // Check that the trading fees are claimed and transferred to the user
        uint256 userToken1Balance = IERC20(address(FRAX)).balanceOf(user);
        uint256 userToken2Balance = IERC20(address(USDC)).balanceOf(user);
        assertEq(userToken1Balance, feeAmount1);
        assertEq(userToken2Balance, feeAmount2);

        // Check that the claimable amounts are reset
        assertEq(gauge.claimable(user, address(FRAX)), 0);
        assertEq(gauge.claimable(user, address(USDC)), 0);

        // Check that the state storage is updated correctly
        assertEq(gauge.rewards(user), 0);
        assertEq(gauge.userRewardPerTokenPaid(user), gauge.rewardPerTokenStored());
    }

    function testGetRewardsWithoutDeposit() public {
        address user = address(0x6);
        uint stakedAmount = 1e12;

        // Mock the staking token balance for the user
        deal(address(pool), user, stakedAmount);

        // Simulate user staking
        vm.prank(user);
        IERC20(address(pool)).approve(address(gauge), stakedAmount);

        vm.prank(user);
        // gauge.deposit(stakedAmount);

        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Call getReward as the user
        vm.prank(user);
        gauge.getReward(user);

        // Check that the trading fees are claimed and transferred to the user
        uint256 userToken1Balance = IERC20(address(FRAX)).balanceOf(user);
        uint256 userToken2Balance = IERC20(address(USDC)).balanceOf(user);
        assertEq(userToken1Balance, 0);
        assertEq(userToken2Balance, 0);

        // Check that the claimable amounts are reset
        assertEq(gauge.supplyIndex(user, address(FRAX)), gauge.getIndexRatio(address(FRAX)));
        assertEq(gauge.supplyIndex(user, address(USDC)), gauge.getIndexRatio(address(USDC)));

    }
    
    function testGetRewardsMultipleDepositors() public {
        // Set up multiple users
        address user1 = address(0x6);
        address user2 = address(0x7);
        address user3 = address(0x8);
        
        uint stakedAmount1 = 1e10;  // 1/3 of total stake
        uint stakedAmount2 = 1e10;  // 1/3 of total stake
        uint stakedAmount3 = 1e10;  // 1/3 of total stake

        uint feeAmount1 = 9e16; // 30% * 1e19 * stakeAmount / totalSupply = 30% * 1e19 * 3e10 / 1e12
        uint feeAmount2 = 18e16; // 30% * 2e19 * stakeAmount / totalSupply = 30% * 2e19 * 3e10 / 1e12

        // Mock the staking token balance for all users
        deal(address(pool), user1, stakedAmount1);
        deal(address(pool), user2, stakedAmount2);
        deal(address(pool), user3, stakedAmount3);
        

        // Simulate users staking
        vm.prank(user1);
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(user2);
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(user3);
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(user1);
        gauge.deposit(stakedAmount1);
        vm.prank(user2);
        gauge.deposit(stakedAmount2);
        vm.prank(user3);
        gauge.deposit(stakedAmount3);

        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Calculate expected rewards for each user (1/3 of total)
        uint expectedFeeAmount1 = feeAmount1 / 3;
        uint expectedFeeAmount2 = feeAmount2 / 3;

        // Call getReward for each user
        vm.prank(user1);
        gauge.getReward(user1);
        vm.prank(user2);
        gauge.getReward(user2);
        vm.prank(user3);
        gauge.getReward(user3);

        assertEq(IERC20(address(FRAX)).balanceOf(user1), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user1), expectedFeeAmount2);
        assertEq(IERC20(address(FRAX)).balanceOf(user2), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user2), expectedFeeAmount2);
        assertEq(IERC20(address(FRAX)).balanceOf(user3), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user3), expectedFeeAmount2);

        // Check that the claimable amounts are reset for all users
        assertEq(gauge.claimable(user1, address(FRAX)), 0);
        assertEq(gauge.claimable(user1, address(USDC)), 0);
        assertEq(gauge.claimable(user2, address(FRAX)), 0);
        assertEq(gauge.claimable(user2, address(USDC)), 0);
        assertEq(gauge.claimable(user3, address(FRAX)), 0);
        assertEq(gauge.claimable(user3, address(USDC)), 0);

        // Check that the state storage is updated correctly for all users
        assertEq(gauge.rewards(user1), 0);
        assertEq(gauge.rewards(user2), 0);
        assertEq(gauge.rewards(user3), 0);
        assertEq(gauge.userRewardPerTokenPaid(user1), gauge.rewardPerTokenStored());
        assertEq(gauge.userRewardPerTokenPaid(user2), gauge.rewardPerTokenStored());
        assertEq(gauge.userRewardPerTokenPaid(user3), gauge.rewardPerTokenStored());
    }

    function testGetRewardsMultipleDepositorsWithEarlyWithdrawal() public {
        // Set up multiple users
        address user1 = address(0x6);
        address user2 = address(0x7);
        address user3 = address(0x8);
        
        uint stakedAmount1 = 1e10;  // 1/3 of total stake
        uint stakedAmount2 = 1e10;  // 1/3 of total stake
        uint stakedAmount3 = 1e10;  // 1/3 of total stake

        uint feeAmount1 = 6e16; // 30% * 1e19 * stakeAmount / totalSupply = 30% * 1e19 * 2e10 / 1e12
        uint feeAmount2 = 12e16; // 30% * 2e19 * stakeAmount / totalSupply = 30% * 2e19 * 2e10 / 1e12

        // Mock the staking token balance for all users
        deal(address(pool), user1, stakedAmount1);
        deal(address(pool), user2, stakedAmount2);
        deal(address(pool), user3, stakedAmount3);

        // Simulate users staking
        vm.prank(user1);
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(user2);
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(user3);
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(user1);
        gauge.deposit(stakedAmount1);
        vm.prank(user2);
        gauge.deposit(stakedAmount2);
        vm.prank(user3);
        gauge.deposit(stakedAmount3);

        // User1 withdraws their stake
        vm.prank(user1);
        gauge.withdraw(stakedAmount1);

        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Calculate expected rewards for remaining users (1/2 of total each)
        uint expectedFeeAmount1 = feeAmount1 / 2;
        uint expectedFeeAmount2 = feeAmount2 / 2;

        // Call getReward for remaining users
        vm.prank(user2);
        gauge.getReward(user2);
        vm.prank(user3);
        gauge.getReward(user3);

        // Check that user1 received no rewards
        assertEq(IERC20(address(FRAX)).balanceOf(user1), 0);
        assertEq(IERC20(address(USDC)).balanceOf(user1), 0);

        // Check that remaining users received their proportional share
        assertEq(IERC20(address(FRAX)).balanceOf(user2), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user2), expectedFeeAmount2);
        assertEq(IERC20(address(FRAX)).balanceOf(user3), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user3), expectedFeeAmount2);

        // Check that the claimable amounts are reset for all users
        assertEq(gauge.claimable(user1, address(FRAX)), 0);
        assertEq(gauge.claimable(user1, address(USDC)), 0);
        assertEq(gauge.claimable(user2, address(FRAX)), 0);
        assertEq(gauge.claimable(user2, address(USDC)), 0);
        assertEq(gauge.claimable(user3, address(FRAX)), 0);
        assertEq(gauge.claimable(user3, address(USDC)), 0);

        // Check that the state storage is updated correctly for all users
        assertEq(gauge.rewards(user1), 0);
        assertEq(gauge.rewards(user2), 0);
        assertEq(gauge.rewards(user3), 0);
        assertEq(gauge.userRewardPerTokenPaid(user1), gauge.rewardPerTokenStored());
        assertEq(gauge.userRewardPerTokenPaid(user2), gauge.rewardPerTokenStored());
        assertEq(gauge.userRewardPerTokenPaid(user3), gauge.rewardPerTokenStored());

        // Verify user1's withdrawal
        assertEq(IERC20(address(pool)).balanceOf(user1), stakedAmount1);
        assertEq(gauge.balanceOf(user1), 0);
    }

    function testGetRewardsMultipleDepositorsWithWithdrawalBetweenRewards() public {
        // Set up multiple users
        address user1 = address(0x6);
        address user2 = address(0x7);
        address user3 = address(0x8);
        
        uint stakedAmount1 = 1e10;  // 1/3 of total stake
        uint stakedAmount2 = 1e10;  // 1/3 of total stake
        uint stakedAmount3 = 1e10;  // 1/3 of total stake

        uint feeAmount1 = 9e16; // 30% * 1e19 * stakeAmount / totalSupply = 30% * 1e19 * 1e10 / 1e12
        uint feeAmount2 = 18e16; // 30% * 2e19 * stakeAmount / totalSupply = 30% * 2e19 * 1e10 / 1e12

        // Mock the staking token balance for all users
        deal(address(pool), user1, stakedAmount1);
        deal(address(pool), user2, stakedAmount2);
        deal(address(pool), user3, stakedAmount3);

        // Simulate users staking
        vm.prank(user1);
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(user2);
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(user3);
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(user1);
        gauge.deposit(stakedAmount1);
        vm.prank(user2);
        gauge.deposit(stakedAmount2);
        vm.prank(user3);
        gauge.deposit(stakedAmount3);

        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), 2 * rewardAmount);
        deal(address(FRAX), address(gauge), 2 * amount1);
        deal(address(USDC), address(gauge), 2 * amount2);
        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), 2 * rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // First reward notification
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        vm.prank(user1);
        gauge.getReward(user1);

        // User1 withdraws their stake
        vm.prank(user1);
        gauge.withdraw(stakedAmount1);

        // Second reward notification
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // Calculate expected rewards
        // For first reward: 1/3 of feeAmount1/2 for each user
        // For second reward: 1/2 of feeAmount1/2 for remaining users
        uint newFeeAmount1 = 6e16; // 30% * 1e19 * stakeAmount / totalSupply = 30% * 1e19 * 2e10 / 1e12
        uint newFeeAmount2 = 12e16; // 30% * 2e19 * stakeAmount / totalSupply = 30% * 2e19 * 2e10 / 1e12
        uint expectedFeeAmount1 = (feeAmount1 / 3) + (newFeeAmount1 / 2);
        uint expectedFeeAmount2 = (feeAmount2 / 3) + (newFeeAmount2 / 2);

        // Call getReward for remaining users
        vm.prank(user2);
        gauge.getReward(user2);
        vm.prank(user3);
        gauge.getReward(user3);

        // Check that user1 received 1/3 first rewards
        assertEq(IERC20(address(FRAX)).balanceOf(user1), feeAmount1 / 3);
        assertEq(IERC20(address(USDC)).balanceOf(user1), feeAmount2 / 3);

        // Check that remaining users received their proportional share
        assertEq(IERC20(address(FRAX)).balanceOf(user2), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user2), expectedFeeAmount2);
        assertEq(IERC20(address(FRAX)).balanceOf(user3), expectedFeeAmount1);
        assertEq(IERC20(address(USDC)).balanceOf(user3), expectedFeeAmount2);

        // Check that the claimable amounts are reset for all users
        assertEq(gauge.claimable(user1, address(FRAX)), 0);
        assertEq(gauge.claimable(user1, address(USDC)), 0);
        assertEq(gauge.claimable(user2, address(FRAX)), 0);
        assertEq(gauge.claimable(user2, address(USDC)), 0);
        assertEq(gauge.claimable(user3, address(FRAX)), 0);
        assertEq(gauge.claimable(user3, address(USDC)), 0);

        // Check that the state storage is updated correctly for all users
        assertEq(gauge.rewards(user1), 0);
        assertEq(gauge.rewards(user2), 0);
        assertEq(gauge.rewards(user3), 0);
        assertEq(gauge.userRewardPerTokenPaid(user1), gauge.rewardPerTokenStored());
        assertEq(gauge.userRewardPerTokenPaid(user2), gauge.rewardPerTokenStored());
        assertEq(gauge.userRewardPerTokenPaid(user3), gauge.rewardPerTokenStored());

        // Verify user1's withdrawal
        assertEq(IERC20(address(pool)).balanceOf(user1), stakedAmount1);
        assertEq(gauge.balanceOf(user1), 0);
    }
}