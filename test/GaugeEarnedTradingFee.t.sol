// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract GaugeEarnedTradingFeeTest is BaseTest {
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
    uint fee0 = 3e18; // 30 * 1e19 / 100;
    uint fee1 = 6e18; //30 * 2e19 / 100;
    

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

    function testEarnedTradingFeeWithNoSupply() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.startPrank(address(address(owner)));
        deal(address(pool), address(owner), TOKEN_1);
        IERC20(address(pool)).approve(address(gauge), TOKEN_1);
        IGauge(address(gauge)).deposit(TOKEN_1);
        vm.stopPrank();

        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Check earned fees when recipient has no supply
        uint256[] memory fees = gauge.earnedTradingFee(address(owner), tokens);
        assertEq(fees[0], 0, "Should have no fees when no supply");
        assertEq(fees[1], 0, "Should have no fees when no supply");
    }

    function testEarnedTradingFeeWithSupplyButNoFees() public {
        // First deposit some tokens
        // address stakingToken = IGauge(gauge).stakingToken();
        deal(address(pool), address(owner), 100e18);
        vm.startPrank(address(owner));
        IERC20(pool).approve(address(gauge), 100e18);
        gauge.deposit(100e18);
        vm.stopPrank();

        // Setup test tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        // Check earned fees when no fees have been distributed
        uint256[] memory fees = gauge.earnedTradingFee(address(owner), tokens);
        assertEq(fees[0], 0, "Should have no fees when no fees distributed");
        assertEq(fees[1], 0, "Should have no fees when no fees distributed");
    }

    function testEarnedTradingFee1Depositor() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.startPrank(address(address(owner)));
        deal(address(pool), address(owner), TOKEN_1);
        IERC20(address(pool)).approve(address(gauge), TOKEN_1);
        IGauge(address(gauge)).deposit(TOKEN_1);
        vm.stopPrank();

        vm.prank(address(voter));
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);

        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // uint balance0 = gauge.balanceOf(address(owner));// = 100e18
        // uint totalSupply = gauge.totalSupply();// = 100e18
        // uint256 ratio0 = gauge.getIndexRatio(address(FRAX));// = (_feeAmount * 1e30) / totalSupply = fee0 * 1e30 / 100e18 = 3e18 * 1e30 / 100e18 = 3e28
        // uint supplyIndex0 = gauge.supplyIndex(address(owner), address(FRAX)) = 0
        // uint share = balance0 * (ratio0 - supplyIndex0) / 1e30 = 100e18 * (3e28 - 0) / 1e30 = 3e18
        //fee0 = claimable[owner][FRAX] + share
        uint256[] memory fees = gauge.earnedTradingFee(address(owner), tokens);
        console.log("Fees: %s", fees[0]);
        console.log("Fees: %s", fees[1]);
        assertEq(fees[0], fee0);
        assertEq(fees[1], fee1);
    }

    function testEarnedTradingFee1DepositorThenGetReward() public {
        // Set up the reward token balance and approval
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        vm.startPrank(address(address(owner)));
        deal(address(pool), address(owner), TOKEN_1);
        IERC20(address(pool)).approve(address(gauge), TOKEN_1);
        IGauge(address(gauge)).deposit(TOKEN_1);
        vm.stopPrank();

        vm.prank(address(voter));

        IERC20(address(VELO)).approve(address(gauge), rewardAmount);
        address[] memory tokens = new address[](2);
        tokens[0] = address(FRAX);  // FRAX
        tokens[1] = address(USDC);  // USDC

        MockPoolFees(address(gauge.poolFees())).setTokens(tokens);

        // Call notifyRewardAmount as the voter
        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        // uint balance0 = gauge.balanceOf(address(owner));// = 100e18
        // uint totalSupply = gauge.totalSupply();// = 100e18
        // uint256 ratio0 = gauge.getIndexRatio(address(FRAX));// = (_feeAmount * 1e30) / totalSupply = fee0 * 1e30 / 100e18 = 3e18 * 1e30 / 100e18 = 3e28
        // uint supplyIndex0 = gauge.supplyIndex(address(owner), address(FRAX)) = 0
        // uint share = balance0 * (ratio0 - supplyIndex0) / 1e30 = 100e18 * (3e28 - 0) / 1e30 = 3e18
        //fee0 = claimable[owner][FRAX] + share
        uint256[] memory fees = gauge.earnedTradingFee(address(owner), tokens);
        assertEq(fees[0], fee0);
        assertEq(fees[1], fee1);

        gauge.getReward(address(owner));
        uint256[] memory feesAfter = gauge.earnedTradingFee(address(owner), tokens);
        assertEq(feesAfter[0], 0);
        assertEq(feesAfter[1], 0);
    }

    function testEarnedTradingFeeMultipleDepositors() public {
        uint stakedAmount1 = 5e10;
        uint stakedAmount2 = 3e10;
        uint stakedAmount3 = 2e10;

        // Mock the staking token balance for all users
        deal(address(pool), address(owner), stakedAmount1);
        deal(address(pool), address(owner2), stakedAmount2);
        deal(address(pool), address(owner3), stakedAmount3);

        // Simulate users staking
        vm.prank(address(owner));
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(address(owner2));
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(address(owner3));
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(address(owner));
        gauge.deposit(stakedAmount1);
        vm.prank(address(owner2));
        gauge.deposit(stakedAmount2);
        vm.prank(address(owner3));
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

        uint256[] memory fee1s = gauge.earnedTradingFee(address(owner), tokens);
        uint256[] memory fee2s = gauge.earnedTradingFee(address(owner2), tokens);
        uint256[] memory fee3s = gauge.earnedTradingFee(address(owner3), tokens);

        assertEq(fee1s[0], fee0/2);
        assertEq(fee1s[1], fee1/2);
        assertEq(fee2s[0], fee0*3/10);
        assertEq(fee2s[1], fee1*3/10);
        assertEq(fee3s[0], fee0*2/10);
        assertEq(fee3s[1], fee1*2/10);

        gauge.getReward(address(owner));
        uint256[] memory fee1sAfter = gauge.earnedTradingFee(address(owner), tokens);

        vm.prank(address(owner2));
        gauge.getReward(address(owner2));
        uint256[] memory fee2sAfter = gauge.earnedTradingFee(address(owner2), tokens);
        // vm.prank(address(owner3));
        // gauge.getReward(address(owner3));
        uint256[] memory fee3sAfter = gauge.earnedTradingFee(address(owner3), tokens);
        assertEq(fee1sAfter[0], 0);
        assertEq(fee1sAfter[1], 0);
        assertEq(fee2sAfter[0], 0);
        assertEq(fee2sAfter[1], 0);
        assertEq(fee3sAfter[0], fee0*2/10);
        assertEq(fee3sAfter[1], fee1*2/10);
    }

    function testEarnedTradingFeeMultipleDepositorsThenGetReward() public {
        uint stakedAmount1 = 5e10;
        uint stakedAmount2 = 3e10;
        uint stakedAmount3 = 2e10;

        // Mock the staking token balance for all users
        deal(address(pool), address(owner), stakedAmount1);
        deal(address(pool), address(owner2), stakedAmount2);
        deal(address(pool), address(owner3), stakedAmount3);

        // Simulate users staking
        vm.prank(address(owner));
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(address(owner2));
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(address(owner3));
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(address(owner));
        gauge.deposit(stakedAmount1);
        vm.prank(address(owner2));
        gauge.deposit(stakedAmount2);
        vm.prank(address(owner3));
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

        uint256[] memory fee1s = gauge.earnedTradingFee(address(owner), tokens);
        uint256[] memory fee2s = gauge.earnedTradingFee(address(owner2), tokens);
        uint256[] memory fee3s = gauge.earnedTradingFee(address(owner3), tokens);

        assertEq(fee1s[0], fee0/2);
        assertEq(fee1s[1], fee1/2);
        assertEq(fee2s[0], fee0*3/10);
        assertEq(fee2s[1], fee1*3/10);
        assertEq(fee3s[0], fee0*2/10);
        assertEq(fee3s[1], fee1*2/10);
    }

    function testEarnedTradingFeeMultipleDepositorsWithEarlyWithdrawal() public {
        uint stakedAmount1 = 5e10;
        uint stakedAmount2 = 3e10;
        uint stakedAmount3 = 2e10;

        // Mock the staking token balance for all users
        deal(address(pool), address(owner), stakedAmount1);
        deal(address(pool), address(owner2), stakedAmount2);
        deal(address(pool), address(owner3), stakedAmount3);

        // Simulate users staking
        vm.prank(address(owner));
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(address(owner2));
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(address(owner3));
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(address(owner));
        gauge.deposit(stakedAmount1);
        vm.prank(address(owner2));
        gauge.deposit(stakedAmount2);
        vm.prank(address(owner3));
        gauge.deposit(stakedAmount3);

        vm.prank(address(owner3));
        gauge.withdraw(stakedAmount3);

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

        uint256[] memory fee1s = gauge.earnedTradingFee(address(owner), tokens);
        uint256[] memory fee2s = gauge.earnedTradingFee(address(owner2), tokens);
        uint256[] memory fee3s = gauge.earnedTradingFee(address(owner3), tokens);

        assertEq(fee1s[0], fee0 * 5 / 8);
        assertEq(fee1s[1], fee1 * 5 / 8);
        assertEq(fee2s[0], fee0 * 3 / 8);
        assertEq(fee2s[1], fee1 * 3 / 8);
        assertEq(fee3s[0], 0);
        assertEq(fee3s[1], 0);
    }

    function testEarnedTradingFeeMultipleDepositorsWithWithdrawalBetweenRewards() public {
        uint stakedAmount1 = 5e10;
        uint stakedAmount2 = 3e10;
        uint stakedAmount3 = 2e10;

        // Mock the staking token balance for all users
        deal(address(pool), address(owner), stakedAmount1);
        deal(address(pool), address(owner2), stakedAmount2);
        deal(address(pool), address(owner3), stakedAmount3);

        // Simulate users staking
        vm.prank(address(owner));
        IERC20(address(pool)).approve(address(gauge), stakedAmount1);
        vm.prank(address(owner2));
        IERC20(address(pool)).approve(address(gauge), stakedAmount2);
        vm.prank(address(owner3));
        IERC20(address(pool)).approve(address(gauge), stakedAmount3);

        vm.prank(address(owner));
        gauge.deposit(stakedAmount1);
        vm.prank(address(owner2));
        gauge.deposit(stakedAmount2);
        vm.prank(address(owner3));
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

        uint256[] memory fee1s = gauge.earnedTradingFee(address(owner), tokens);
        uint256[] memory fee2s = gauge.earnedTradingFee(address(owner2), tokens);
        uint256[] memory fee3s = gauge.earnedTradingFee(address(owner3), tokens);

        assertEq(fee1s[0], fee0/2);
        assertEq(fee1s[1], fee1/2);
        assertEq(fee2s[0], fee0*3/10);
        assertEq(fee2s[1], fee1*3/10);
        assertEq(fee3s[0], fee0*2/10);
        assertEq(fee3s[1], fee1*2/10);

        vm.prank(address(owner));
        gauge.getReward(address(owner));
        uint256[] memory fee1sAfter = gauge.earnedTradingFee(address(owner), tokens);
        uint256[] memory fee2sAfter = gauge.earnedTradingFee(address(owner2), tokens);
        uint256[] memory fee3sAfter = gauge.earnedTradingFee(address(owner3), tokens);
        assertEq(fee1sAfter[0], 0);
        assertEq(fee1sAfter[1], 0);
        assertEq(fee2sAfter[0], fee0*3/10);
        assertEq(fee2sAfter[1], fee1*3/10);
        assertEq(fee3sAfter[0], fee0*2/10);
        assertEq(fee3sAfter[1], fee1*2/10);

        vm.prank(address(owner));
        gauge.withdraw(stakedAmount1); // owner withdraw

        vm.startPrank(address(voter));
        deal(address(VELO), address(voter), rewardAmount);
        deal(address(FRAX), address(gauge), amount1);
        deal(address(USDC), address(gauge), amount2);
        IERC20(address(VELO)).approve(address(gauge), rewardAmount);
        gauge.notifyRewardAmount(rewardAmount);
        vm.stopPrank();
        uint256[] memory fee1sAfter2 = gauge.earnedTradingFee(address(owner), tokens);
        uint256[] memory fee2sAfter2 = gauge.earnedTradingFee(address(owner2), tokens);
        uint256[] memory fee3sAfter2 = gauge.earnedTradingFee(address(owner3), tokens);
        assertEq(fee1sAfter2[0], 0);
        assertEq(fee1sAfter2[1], 0);
        assertEq(fee2sAfter2[0], fee0*3/10 + fee0*3/5); // first notify + second notify
        assertEq(fee2sAfter2[1], fee1*3/10 + fee1*3/5);
        assertEq(fee3sAfter2[0], fee0*2/10 + fee0*2/5);
        assertEq(fee3sAfter2[1], fee1*2/10 + fee1*2/5);
    }
}