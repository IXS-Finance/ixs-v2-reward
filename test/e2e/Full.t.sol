// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./ForkedBaseTest.sol";
import {NotForTest_DeployVelodromeV2} from "../../script/NotForTest-DeployVelodromeV2.s.sol";
interface IAuthorizer {
    function grantRoles(bytes32[] memory roles, address account) external;
}
interface IPF{
    function setVoter(address _voter) external;
    function feesAmounts(bytes32 poolId, address token) external view returns (uint256);
    function availableDeposit() external view returns (uint256);
    function deposit(uint256 amount) external;
}

contract FullFlow is ForkedBaseTest {
    address myA = 0x31d3892EC556D1656F907A621DDf684aa241cEB2;
    address testToken1 = 0x142953B2F88D0939FD9f48F4bFfa3A2BFa21e4F8;
    address testToken2 = 0xA9c2c7D5E9bdA19bF9728384FFD3cF71Ada5dfcB;
    address _pool = 0xfd97b271Eb0E43C54914D903c8d6351a28FfFe28;
    address authorizer = 0x4769bf4f22bC0Fd4e2C99c697D8b94D51116dD6C;
    address _poolFee = 0xa43bc6300c60F8ff7f9de0FA04AdD375AD0E0454;
    address authorizerAdmin = 0xD9D092E5B1C6F2B50de5f52A4D00ad97E21A64f5;

    // Create test accounts
    address user1 = address(0x6);
    address user2 = address(0x7);
    address user3 = address(0x8);
    function _setUp() public override {
        skip(1 hours);
        deal(address(VELO), myA, TOKEN_1 * 10);
        vm.startPrank(myA);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);

        // grant permission to myA for calling setVoter in PoolFees
        // call setVoter in PoolFees
        vm.stopPrank();
        vm.startPrank(authorizerAdmin);
        bytes32[] memory roles = new bytes32[](1);
        bytes4 sig = 0x4bc2a657;

        bytes32 actionId = keccak256(abi.encodePacked(address(_poolFee), sig));
        roles[0] = actionId;
        IAuthorizer(authorizer).grantRoles(roles, myA);
        vm.stopPrank();
        vm.startPrank(myA);
        IPF(address(_poolFee)).setVoter(address(voter));
        vm.stopPrank();
        skip(1);
    }

    function testGetReward() public{
        skip(1);
        IVoter(address(voter)).createGauge(address(factory), _pool);
        address gauge = IVoter(address(voter)).gauges(_pool);
        console.log("gauge", gauge);
        console.log('poolForGauge', IVoter(address(voter)).poolForGauge(gauge));

        address[] memory pools = new address[](1);
        pools[0] = _pool;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 100e18;
        address[] memory rewards = new address[](2);
        rewards[0] = address(testToken1);
        rewards[1] = address(testToken2);

        // Deposit to gauge
        uint256 depositAmount = IERC20(_pool).balanceOf(myA);
        vm.startPrank(myA);
        IERC20(_pool).approve(address(gauge), depositAmount/100);
        IGauge(gauge).deposit(depositAmount/100);
        assertEq(IERC20(gauge).balanceOf(myA), depositAmount/100);

        vm.stopPrank();

        // Vote for pool
        vm.startPrank(myA);
        voter.vote(1, pools, weights);
        vm.stopPrank();

        address _team = IRewardsDistributor(minter).team();
        vm.startPrank(_team);
        deal(address(VELO), _team, 15e24);
        uint rewardsAmount = 15e24;
        VELO.approve(address(minter), rewardsAmount);
        IPF(address(minter)).deposit(rewardsAmount);
        assertEq(IERC20(address(VELO)).balanceOf(address(minter)), rewardsAmount);
        assertEq(IPF(address(minter)).availableDeposit(), rewardsAmount);
        vm.stopPrank();
        uint feesAmounts = IPF(_poolFee).feesAmounts(0xFD97B271EB0E43C54914D903C8D6351A28FFFE28000200000000000000000003, address(testToken1));
        console.log("feesAmounts", feesAmounts);

        vm.startPrank(myA);
        
        skip(2 weeks + 1 hours);
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        IVoter(voter).distribute(gauges);
        address feesVotingReward = IGauge(gauge).feesVotingReward();
        assertEq(IERC20(address(testToken1)).balanceOf(address(feesVotingReward)), feesAmounts * IVoter(voter).feeForVe() / 10000);
        assertEq(IERC20(address(testToken2)).balanceOf(address(feesVotingReward)), 0);
        assertEq(IERC20(address(testToken1)).balanceOf(address(gauge)), feesAmounts - feesAmounts * IVoter(voter).feeForVe() / 10000);

        // Get rewards
        skip(1 days);

        IVoter(voter).claimRewards(gauges);

        address[] memory bribes = new address[](1);
        bribes[0] = IGauge(gauge).feesVotingReward();

        skip(13 days);
        address[][] memory rewardss = new address[][](1);
        rewardss[0] = new address[](2);
        rewardss[0][0] = address(testToken1);
        rewardss[0][1] = address(testToken2);
        rewards[0] = address(testToken1);
        rewards[1] = address(testToken2);

        uint beforeClaim1 = IERC20(address(testToken1)).balanceOf(myA);
        uint beforeClaim2 = IERC20(address(testToken2)).balanceOf(myA);
        IVoter(voter).claimBribes(bribes, rewardss, 1);
        assertEq(IERC20(address(testToken1)).balanceOf(myA), beforeClaim1 + feesAmounts * IVoter(voter).feeForVe() / 10000);
        assertEq(IERC20(address(testToken2)).balanceOf(myA), beforeClaim2);
        vm.stopPrank();
    }

    function testMultipleDepositors() public {
        // Setup initial balances for users
        deal(address(VELO), user1, TOKEN_1 * 10);
        deal(address(VELO), user2, TOKEN_1 * 10);
        deal(address(VELO), user3, TOKEN_1 * 10);

        vm.startPrank(user1);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);
        vm.stopPrank();

        vm.startPrank(user2);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);
        vm.stopPrank();
        vm.startPrank(user3);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);
        vm.stopPrank();

        // Create gauge
        IVoter(address(voter)).createGauge(address(factory), _pool);
        address gauge = IVoter(address(voter)).gauges(_pool);

        // Setup voting parameters
        address[] memory pools = new address[](1);
        pools[0] = _pool;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 100e18;
        address[] memory rewards = new address[](2);
        rewards[0] = address(testToken1);
        rewards[1] = address(testToken2);

        uint depositAmount = IERC20(_pool).balanceOf(myA)/100;

        deal(address(_pool), user1, depositAmount);
        deal(address(_pool), user2, depositAmount);
        deal(address(_pool), user3, depositAmount);

        // User1 deposit and vote
        vm.startPrank(user1);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(2, pools, weights);
        vm.stopPrank();

        // User2 deposit and vote
        vm.startPrank(user2);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(3, pools, weights);
        vm.stopPrank();

        // User3 deposit and vote
        vm.startPrank(user3);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(4, pools, weights);
        vm.stopPrank();

        // Verify deposits
        assertEq(IERC20(gauge).balanceOf(user1), depositAmount);
        assertEq(IERC20(gauge).balanceOf(user2), depositAmount);
        assertEq(IERC20(gauge).balanceOf(user3), depositAmount);
        assertEq(IERC20(gauge).totalSupply(), depositAmount * 3);

        // Setup rewards
        address _team = IRewardsDistributor(minter).team();
        vm.startPrank(_team);
        deal(address(VELO), _team, 15e24);
        uint rewardsAmount = 15e24;
        VELO.approve(address(minter), rewardsAmount);
        IPF(address(minter)).deposit(rewardsAmount);
        vm.stopPrank();

        // Get fees amount
        uint feesAmounts = IPF(_poolFee).feesAmounts(0xFD97B271EB0E43C54914D903C8D6351A28FFFE28000200000000000000000003, address(testToken1));

        // Distribute rewards
        skip(2 weeks + 1 hours);
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        IVoter(voter).distribute(gauges);

        // Verify fee distribution
        address feesVotingReward = IGauge(gauge).feesVotingReward();
        uint256 expectedFees = feesAmounts * IVoter(voter).feeForVe() / 10000;
        assertEq(IERC20(address(testToken1)).balanceOf(address(feesVotingReward)), expectedFees);
        assertEq(IERC20(address(testToken2)).balanceOf(address(feesVotingReward)), 0);
        assertEq(IERC20(address(testToken1)).balanceOf(address(gauge)), feesAmounts - expectedFees);

        // Claim rewards
        skip(1 days);
        IVoter(voter).claimRewards(gauges);

        // Setup bribe claiming
        address[] memory bribes = new address[](1);
        bribes[0] = IGauge(gauge).feesVotingReward();
        address[][] memory rewardss = new address[][](1);
        rewardss[0] = new address[](2);
        rewardss[0][0] = address(testToken1);
        rewardss[0][1] = address(testToken2);

        // Claim bribes for all users
        skip(13 days);
        vm.startPrank(user1);
        IVoter(voter).claimBribes(bribes, rewardss, 2);
        vm.stopPrank();

        vm.startPrank(user2);
        IVoter(voter).claimBribes(bribes, rewardss, 3);
        vm.stopPrank();

        vm.startPrank(user3);
        IVoter(voter).claimBribes(bribes, rewardss, 4);
        vm.stopPrank();

        // Verify equal distribution of rewards
        uint256 expectedReward = expectedFees / 3; // Each user should get 1/3 of the fees
        assertEq(IERC20(address(testToken1)).balanceOf(user1), expectedReward);
        assertEq(IERC20(address(testToken1)).balanceOf(user2), expectedReward);
        assertEq(IERC20(address(testToken1)).balanceOf(user3), expectedReward);
        assertEq(IERC20(address(testToken2)).balanceOf(user1), 0);
        assertEq(IERC20(address(testToken2)).balanceOf(user2), 0);
        assertEq(IERC20(address(testToken2)).balanceOf(user3), 0);
    }

    function testMultipleDepositorsWithEarlyWithdrawal() public {
        // Setup initial balances for users
        deal(address(VELO), user1, TOKEN_1 * 10);
        deal(address(VELO), user2, TOKEN_1 * 10);
        deal(address(VELO), user3, TOKEN_1 * 10);

        // Create locks for all users
        vm.startPrank(user1);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);
        vm.stopPrank();

        vm.startPrank(user2);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);
        vm.stopPrank();

        vm.startPrank(user3);
        VELO.approve(address(escrow), TOKEN_1);
        escrow.createLock(TOKEN_1, MAX_TIME);
        vm.stopPrank();

        // Create gauge
        IVoter(address(voter)).createGauge(address(factory), _pool);
        address gauge = IVoter(address(voter)).gauges(_pool);

        // Setup voting parameters
        address[] memory pools = new address[](1);
        pools[0] = _pool;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 100e18;
        address[] memory rewards = new address[](2);
        rewards[0] = address(testToken1);
        rewards[1] = address(testToken2);

        // Setup deposit amounts
        uint depositAmount = IERC20(_pool).balanceOf(myA)/100;

        // Distribute pool tokens to all users
        deal(address(_pool), myA, depositAmount);
        deal(address(_pool), user1, depositAmount);
        deal(address(_pool), user2, depositAmount);
        deal(address(_pool), user3, depositAmount);

        // myA deposit and vote
        vm.startPrank(myA);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(1, pools, weights);
        vm.stopPrank();

        // User1 deposit and vote
        vm.startPrank(user1);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(2, pools, weights);
        vm.stopPrank();

        // User2 deposit and vote
        vm.startPrank(user2);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(3, pools, weights);
        vm.stopPrank();

        // User3 deposit and vote
        vm.startPrank(user3);
        IERC20(_pool).approve(address(gauge), depositAmount);
        IGauge(gauge).deposit(depositAmount);
        voter.vote(4, pools, weights);
        vm.stopPrank();

        // Verify initial deposits
        assertEq(IERC20(gauge).balanceOf(myA), depositAmount);
        assertEq(IERC20(gauge).balanceOf(user1), depositAmount);
        assertEq(IERC20(gauge).balanceOf(user2), depositAmount);
        assertEq(IERC20(gauge).balanceOf(user3), depositAmount);
        assertEq(IERC20(gauge).totalSupply(), depositAmount * 4);

        // Setup rewards
        address _team = IRewardsDistributor(minter).team();
        vm.startPrank(_team);
        deal(address(VELO), _team, 15e24);
        uint rewardsAmount = 15e24;
        VELO.approve(address(minter), rewardsAmount);
        IPF(address(minter)).deposit(rewardsAmount);
        vm.stopPrank();

        // Get fees amount
        uint feesAmounts = IPF(_poolFee).feesAmounts(0xFD97B271EB0E43C54914D903C8D6351A28FFFE28000200000000000000000003, address(testToken1));

        // Distribute rewards
        skip(2 weeks + 1 hours);
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        IVoter(voter).distribute(gauges);

        // Verify fee distribution
        address feesVotingReward = IGauge(gauge).feesVotingReward();
        uint256 expectedFees = feesAmounts * IVoter(voter).feeForVe() / 10000;
        assertEq(IERC20(address(testToken1)).balanceOf(address(feesVotingReward)), expectedFees);
        assertEq(IERC20(address(testToken2)).balanceOf(address(feesVotingReward)), 0);
        assertEq(IERC20(address(testToken1)).balanceOf(address(gauge)), feesAmounts - expectedFees);

        // User1 withdraws early
        vm.startPrank(user1);
        IGauge(gauge).withdraw(depositAmount);
        vm.stopPrank();

        // Verify withdrawal
        assertEq(IERC20(gauge).balanceOf(user1), 0);
        assertEq(IERC20(_pool).balanceOf(user1), depositAmount);
        assertEq(IERC20(gauge).totalSupply(), depositAmount * 3);

        // Claim rewards
        skip(1 days);
        IVoter(voter).claimRewards(gauges);

        // Setup bribe claiming
        address[] memory bribes = new address[](1);
        bribes[0] = IGauge(gauge).feesVotingReward();
        address[][] memory rewardss = new address[][](1);
        rewardss[0] = new address[](2);
        rewardss[0][0] = address(testToken1);
        rewardss[0][1] = address(testToken2);

        // Claim bribes for remaining users
        skip(13 days);
        uint beforeClaim1 = IERC20(address(testToken1)).balanceOf(myA);
        vm.startPrank(myA);
        IVoter(voter).claimBribes(bribes, rewardss, 1);
        vm.stopPrank();

        vm.startPrank(user2);
        IVoter(voter).claimBribes(bribes, rewardss, 3);
        vm.stopPrank();

        vm.startPrank(user3);
        IVoter(voter).claimBribes(bribes, rewardss, 4);
        vm.stopPrank();

        // Verify reward distribution
        uint256 expectedReward = expectedFees / 4; // Each remaining user should get 1/4 of the fees
        assertEq(IERC20(address(testToken1)).balanceOf(myA), beforeClaim1 + expectedReward);
        assertEq(IERC20(address(testToken1)).balanceOf(user2), expectedReward);
        assertEq(IERC20(address(testToken1)).balanceOf(user3), expectedReward);
        assertEq(IERC20(address(testToken1)).balanceOf(user1), 0);
        assertEq(IERC20(address(testToken2)).balanceOf(user1), 0);
        assertEq(IERC20(address(testToken2)).balanceOf(user2), 0);
        assertEq(IERC20(address(testToken2)).balanceOf(user3), 0);

        vm.startPrank(user1);
        IVoter(voter).claimBribes(bribes, rewardss, 2);
        vm.stopPrank();
        assertEq(IERC20(address(testToken1)).balanceOf(user1), expectedReward);

    }
}
