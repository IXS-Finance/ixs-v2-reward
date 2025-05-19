// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IVoter} from "../interfaces/IVoter.sol";
import {IGauge} from "../interfaces/IGauge.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IBalancerPool} from "../interfaces/IBalancerPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {VotingReward} from "../rewards/VotingReward.sol";
import {IReward} from "../interfaces/IReward.sol";
import {IRewardSugar} from "../interfaces/IRewardSugar.sol";
import {Reward} from "../rewards/Reward.sol";


/**
 * @title RewardHelper
 * @notice Helper contract to fetch voting rewards (fees and bribes)
 */
contract RewardSugar is IRewardSugar { 
    IVoter public immutable voter;
    uint256 public constant DURATION = 14 days;
    constructor(address _voter) {
        require(_voter != address(0), "Invalid voter address");
        
        voter = IVoter(_voter);
    }

    function _getEarned(
        uint256 _tokenId,
        address _votingReward
    ) internal view returns (address[] memory, uint256[] memory) {
        // Calculate total number of rewards
        uint256 totalLength = IReward(_votingReward).rewardsListLength();
        require(totalLength > 0, "No rewards found");

        // Initialize rewards array
        uint256[] memory rewards = new uint256[](totalLength);
        address[] memory tokens = new address[](totalLength);

        // Get fee rewards for pool tokens
        for (uint256 i = 0; i < totalLength; i++) {
            address token = address(Reward(_votingReward).rewards(i));
            uint256 earnedAmount = IReward(_votingReward).earned(token, _tokenId);
            rewards[i] = earnedAmount;
            tokens[i] = token;
            
        }
        return (tokens, rewards);
    }

    function getFeeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint[] memory rewards) {
        require(_pool != address(0), "Invalid pool address");

        address _gauge = IVoter(voter).gauges(_pool);
        require(_gauge != address(0), "Invalid gauge address");
        address feeVotingReward = voter.gaugeToFees(_gauge);
        (tokens, rewards) = _getEarned(_tokenId, feeVotingReward);
    }

    function getBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint[] memory rewards) {
        require(_pool != address(0), "Invalid pool address");

        address _gauge = IVoter(voter).gauges(_pool);
        require(_gauge != address(0), "Invalid gauge address");
        address bribeVotingReward = voter.gaugeToBribe(_gauge);

        (tokens, rewards) = _getEarned(_tokenId, bribeVotingReward);
    }

    function getFeeAndBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory feeTokens, address[] memory bribeTokens, uint[] memory feeRewards, uint[] memory bribeRewards) {
        require(_pool != address(0), "Invalid pool address");

        address _gauge = IVoter(voter).gauges(_pool);
        require(_gauge != address(0), "Invalid gauge address");
        address bribeVotingReward = voter.gaugeToBribe(_gauge);
        address feeVotingReward = voter.gaugeToFees(_gauge);
        (feeTokens, feeRewards) = _getEarned(_tokenId, feeVotingReward);
        (bribeTokens, bribeRewards) = _getEarned(_tokenId, bribeVotingReward);
    }

    function getFeeAndBribeVotingRewardsForTokenIdAndPools(
        address[] calldata _pools,
        uint256 _tokenId
    ) external view returns (address[][] memory feeTokens, address[][] memory bribeTokens, uint[][] memory feeRewards, uint[][] memory bribeRewards) {
        uint256 length = _pools.length;
        feeRewards = new uint[][](length);
        bribeRewards = new uint[][](length);
        feeTokens = new address[][](length);
        bribeTokens = new address[][](length);
        for (uint256 i = 0; i < length; i++) {
            require(_pools[i] != address(0), "Invalid pool address");

            address _gauge = IVoter(voter).gauges(_pools[i]);
            require(_gauge != address(0), "Invalid gauge address");
            address feeVotingReward = voter.gaugeToFees(_gauge);
            address bribeVotingReward = voter.gaugeToBribe(_gauge);
            (feeTokens[i], feeRewards[i]) = _getEarned(_tokenId, feeVotingReward);
            (bribeTokens[i], bribeRewards[i]) = _getEarned(_tokenId, bribeVotingReward);
        }
    }

    function _getRewards(
        address _votingReward,
        uint256 _timestamp
    ) internal view returns (address[] memory, uint256[] memory) {
        // Calculate total number of rewards
        uint256 totalLength = IReward(_votingReward).rewardsListLength();
        require(totalLength > 0, "No rewards found");

        // Calculate the epoch start time
        uint epochStart = _timestamp - (_timestamp % DURATION);

        // Initialize rewards array
        uint256[] memory rewards = new uint256[](totalLength);
        address[] memory tokens = new address[](totalLength);


        // Get fee rewards for pool tokens
        for (uint256 i = 0; i < totalLength; i++) {
            address token = address(Reward(_votingReward).rewards(i));
            uint256 earnedAmount = IReward(_votingReward).tokenRewardsPerEpoch(token, epochStart);
            rewards[i] = earnedAmount;
            tokens[i] = token;
            
        }
        return (tokens, rewards);
    }
    

    function getFeeAndBribeVotingRewardsOfPools(
        address[] calldata _pools,
        uint256 _timestamp
    ) external view returns (address[][] memory feeTokens, address[][] memory bribeTokens, uint[][] memory feeRewards, uint[][] memory bribeRewards) {
        uint256 length = _pools.length;
        feeRewards = new uint[][](length);
        bribeRewards = new uint[][](length);
        feeTokens = new address[][](length);
        bribeTokens = new address[][](length);
        for (uint256 i = 0; i < length; i++) {
            require(_pools[i] != address(0), "Invalid pool address");

            address _gauge = IVoter(voter).gauges(_pools[i]);
            require(_gauge != address(0), "Invalid gauge address");
            address feeVotingReward = voter.gaugeToFees(_gauge);
            address bribeVotingReward = voter.gaugeToBribe(_gauge);
            (feeTokens[i], feeRewards[i]) = _getRewards(feeVotingReward, _timestamp);
            (bribeTokens[i], bribeRewards[i]) = _getRewards(bribeVotingReward, _timestamp);
        }
    }

}