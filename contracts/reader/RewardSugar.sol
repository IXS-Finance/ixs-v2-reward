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

/**
 * @title VotingRewardHelper
 * @notice Helper contract to fetch voting rewards (fees and bribes)
 */
contract RewardSugar is IRewardSugar { 
    IVoter public immutable voter;
    IVault public immutable vault;
    IVotingEscrow public immutable ve;

    constructor(address _voter, address _vault) {
        require(_voter != address(0), "Invalid voter address");
        require(_vault != address(0), "Invalid vault address");
        
        voter = IVoter(_voter);
        vault = IVault(_vault);
        ve = IVotingEscrow(voter.ve());
    }

    function _getEarned(
        address _pool,
        uint256 _tokenId,
        address _votingReward
    ) internal view returns (uint256[] memory) {
        require(_pool != address(0), "Invalid pool address");
        bytes32 poolId = IBalancerPool(_pool).getPoolId();
        (IERC20[] memory poolTokens,,) = vault.getPoolTokens(poolId);

        // Calculate total number of rewards
        uint256 totalLength = poolTokens.length;

        // Initialize rewards array
        uint256[] memory rewards = new uint256[](totalLength);

        // Get fee rewards for pool tokens
        for (uint256 i = 0; i < poolTokens.length; i++) {
            address token = address(poolTokens[i]);
            uint256 earnedAmount = IReward(_votingReward).earned(token, _tokenId);
            rewards[i] = earnedAmount;
        }
        return rewards;
    }

    function _getPoolTokens(
        address pool
    ) internal view returns (address[] memory) {
        // Get pool tokens for fee rewards
        bytes32 poolId = IBalancerPool(pool).getPoolId();
        (IERC20[] memory poolTokens,,) = vault.getPoolTokens(poolId);
        uint256 totalLength = poolTokens.length;
        address[] memory tokens = new address[](totalLength);
        for (uint256 i = 0; i < poolTokens.length; i++) {
            address token = address(poolTokens[i]);
            tokens[i] = token;
        }
        return tokens;
    }

    function _getFeeAndBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) internal view returns (uint[] memory feeRewards, uint[] memory bribeRewards) {
        require(_pool != address(0), "Invalid pool address");

        address _gauge = IVoter(voter).gauges(_pool);
        require(_gauge != address(0), "Invalid gauge address");
        
        address feeVotingReward = voter.gaugeToFees(_gauge);
        address bribeVotingReward = voter.gaugeToBribe(_gauge);

        feeRewards = _getEarned(_pool, _tokenId, feeVotingReward);
        bribeRewards = _getEarned(_pool, _tokenId, bribeVotingReward);
    }

    function getFeeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint[] memory rewards) {
        require(_pool != address(0), "Invalid pool address");

        address _gauge = IVoter(voter).gauges(_pool);
        require(_gauge != address(0), "Invalid gauge address");
        address feeVotingReward = voter.gaugeToFees(_gauge);
        rewards = _getEarned(_pool, _tokenId, feeVotingReward);
        tokens = _getPoolTokens(_pool);
    }

    function getBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint[] memory rewards) {
        require(_pool != address(0), "Invalid pool address");

        address _gauge = IVoter(voter).gauges(_pool);
        require(_gauge != address(0), "Invalid gauge address");
        address bribeVotingReward = voter.gaugeToBribe(_gauge);

        rewards = _getEarned(_pool, _tokenId, bribeVotingReward);
        tokens = _getPoolTokens(_pool);
    }

    function getFeeAndBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint[] memory feeRewards, uint[] memory bribeRewards) {
        (feeRewards, bribeRewards) = _getFeeAndBribeVotingRewards(_pool, _tokenId);
        tokens = _getPoolTokens(_pool);
    }

    function getFeeAndBribeVotingRewardsForOneTokenIdAndMultipleGauges(
        address[] calldata _pools,
        uint256 _tokenId
    ) external view returns (address[][] memory tokens, uint[][] memory feeRewards, uint[][] memory bribeRewards) {
        uint256 length = _pools.length;
        feeRewards = new uint[][](length);
        bribeRewards = new uint[][](length);
        tokens = new address[][](length);
        
        for (uint256 i = 0; i < length; i++) {
            (feeRewards[i], bribeRewards[i]) = _getFeeAndBribeVotingRewards(_pools[i], _tokenId);
            tokens[i] = _getPoolTokens(_pools[i]);
        }
    }

}