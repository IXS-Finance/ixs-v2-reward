// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import "../contracts/reader/RewardSugar.sol";
import "../contracts/interfaces/IRewardSugar.sol";

contract RewardSugarTest is BaseTest {
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
    address rewardSugar;

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

        // skipToNextEpoch(0);
        team = escrow.team();
        poolFee = gauge.poolFees();

        rewardSugar = address(new RewardSugar(address(voter)));
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

        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

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

        skipToNextEpoch(1 hours + 1);
        voter.vote(1, pools, weights);

        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        skipToNextEpoch(1);

        uint feesBalanceFRAX = IERC20(FRAX).balanceOf(address(feesVotingReward));
        uint feesBalanceUSDC = IERC20(USDC).balanceOf(address(feesVotingReward));

        ( ,uint256[] memory feeVotingReward) = IRewardSugar(rewardSugar).getFeeVotingRewards(address(pool), 1);

        address[] memory _pools = new address[](1);
        _pools[0] = address(pool);
        (address[][] memory feeTokens1, ,uint256[][] memory feeVotingReward1, ) = IRewardSugar(rewardSugar).getFeeAndBribeVotingRewardsForTokenIdAndPools(_pools, 1);

        (address[] memory feeTokens2, ,uint256[] memory feeVotingReward2, ) = IRewardSugar(rewardSugar).getFeeAndBribeVotingRewards(address(pool), 1);

        assertEq(feeTokens1[0][0], address(USDC));
        assertEq(feeTokens1[0][1], address(FRAX));
        assertEq(feeTokens2[0], address(USDC));
        assertEq(feeTokens2[1], address(FRAX));
        assertEq(feeVotingReward[0], feesBalanceUSDC);
        assertEq(feeVotingReward[1], feesBalanceFRAX);
        assertEq(feeVotingReward1[0][0], feesBalanceUSDC);
        assertEq(feeVotingReward1[0][1], feesBalanceFRAX);
        assertEq(feeVotingReward2[0], feesBalanceUSDC);
        assertEq(feeVotingReward2[1], feesBalanceFRAX);
    }

    function testGetFeeAndBribeVotingRewardsForEpoch() public {
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

        address[] memory pools = new address[](1);
        pools[0] = address(pool);
        uint256[] memory weights = new uint256[](1);
        weights[0] = 10000;

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

        skipToNextEpoch(1 hours + 1);
        voter.vote(1, pools, weights);

        vm.prank(address(voter));
        gauge.notifyRewardAmount(rewardAmount);

        uint feesBalanceFRAX = IERC20(FRAX).balanceOf(address(feesVotingReward));
        uint feesBalanceUSDC = IERC20(USDC).balanceOf(address(feesVotingReward));

        address[] memory _pools = new address[](1);
        _pools[0] = address(pool);

        // Use a fixed timestamp variable instead of block.timestamp for security/no-block-members
        uint256 currentTimestamp = block.timestamp;

        // Adjust the destructuring to match the actual return values of the function
        (
            address[][] memory feeTokens1, , uint256[][] memory feeVotingReward1,
        ) = IRewardSugar(rewardSugar).getFeeAndBribeVotingRewardsOfPools(_pools, currentTimestamp);

        assertEq(feeTokens1[0][0], address(USDC));
        assertEq(feeTokens1[0][1], address(FRAX));
        assertEq(feeVotingReward1[0][0], feesBalanceUSDC);
        assertEq(feeVotingReward1[0][1], feesBalanceFRAX);

    }
}