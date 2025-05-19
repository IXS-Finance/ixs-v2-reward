// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRewardSugar {
    /*
     * @notice Get the earned fees for a specific pool and tokenId
     * @param _pool The address of the pool
     * @param _tokenId The lock Id of the user
     * @return tokens The addresses of the tokens in the pool
     * @return rewards The amounts of the tokens earned
     */
    function getFeeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint256[] memory rewards);

    /*
     * @notice Get the earned bribes for a specific pool and tokenId
     * @param _pool The address of the pool
     * @param _tokenId The lock Id of the user
     * @return tokens The addresses of the tokens in the pool
     * @return rewards The amounts of the tokens earned
     */
    function getBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint256[] memory rewards);

    /*
     * @notice Get the earned fees and bribes for a specific pool and tokenId
     * @param _pool The address of the pool
     * @param _tokenId The lock Id of the user
     * @return feeTokens The addresses of the fee reward tokens in the pool
     * @return bribeTokens The addresses of the bribe reward tokens in the pool
     * @return fees The amounts of the fees earned
     * @return bribes The amounts of the bribes earned
     */
    function getFeeAndBribeVotingRewards(
        address _pool,
        uint256 _tokenId
    ) external view returns (address[] memory feeTokens, address[] memory bribeTokens, uint256[] memory fees, uint256[] memory bribes);

    /*
     * @notice Get the earned fees and bribes for multiple pools and tokenId
     * @param _pools The addresses of the pools
     * @param _tokenId The lock Id of the user
     * @return feeTokens The addresses of the fee reward tokens in the pool
     * @return bribeTokens The addresses of the bribe reward tokens in the pool
     * @return fees The amounts of the fees earned
     * @return bribes The amounts of the bribes earned
     */
    function getFeeAndBribeVotingRewardsForTokenIdAndPools(
        address[] calldata _pools,
        uint256 _tokenId
    ) external view returns (address[][] memory feeTokens, address[][] memory bribeTokens, uint[][] memory feeRewards, uint[][] memory bribeRewards);


    function getFeeAndBribeVotingRewardsOfPools(
        address[] calldata _pools,
        uint256 _timestamp
    ) external view returns (address[][] memory feeTokens, address[][] memory bribeTokens, uint[][] memory feeRewards, uint[][] memory bribeRewards);
}