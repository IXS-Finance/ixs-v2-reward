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
}

contract FullFlow is ForkedBaseTest {
    address myA = 0x31d3892EC556D1656F907A621DDf684aa241cEB2;
    address testToken1 = 0x142953B2F88D0939FD9f48F4bFfa3A2BFa21e4F8;
    address testToken2 = 0xA9c2c7D5E9bdA19bF9728384FFD3cF71Ada5dfcB;
    address _pool = 0xfd97b271Eb0E43C54914D903c8d6351a28FfFe28;
    address authorizer = 0x4769bf4f22bC0Fd4e2C99c697D8b94D51116dD6C;
    address _poolFee = 0xa43bc6300c60F8ff7f9de0FA04AdD375AD0E0454;
    address authorizerAdmin = 0xD9D092E5B1C6F2B50de5f52A4D00ad97E21A64f5;
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
        weights[0] = 10000;
        address[] memory rewards = new address[](2);
        rewards[0] = address(testToken1);
        rewards[1] = address(testToken2);

        // Deposit to gauge
        uint256 depositAmount = 20217892403460031812490;
        vm.startPrank(myA);
        IERC20(_pool).approve(address(gauge), depositAmount/100);
        IGauge(gauge).deposit(depositAmount/100);
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
        IRewardsDistributor(address(minter)).deposit(rewardsAmount);
        vm.stopPrank();
        uint feesAmounts = IPF(_poolFee).feesAmounts(0xFD97B271EB0E43C54914D903C8D6351A28FFFE28000200000000000000000003, address(testToken1));
        console.log("feesAmounts", feesAmounts);

        vm.startPrank(myA);
        
        // Warp 2 days
        skip(2 days);
        address[] memory gauges = new address[](1);
        gauges[0] = gauge;
        IVoter(voter).distribute(gauges);

        // Get rewards
        skip(2 days);

        IVoter(voter).claimRewards(gauges);

        address[] memory bribes = new address[](1);
        bribes[0] = IGauge(gauge).feesVotingReward();

        address[][] memory rewardss = new address[][](1);
        rewardss[0] = new address[](2);
        rewardss[0][0] = address(testToken1);
        rewardss[0][1] = address(testToken2);
        rewards[0] = address(testToken1);
        rewards[1] = address(testToken2);

        IVoter(voter).claimBribes(bribes, rewardss, 1);
        vm.stopPrank();
    }

}
