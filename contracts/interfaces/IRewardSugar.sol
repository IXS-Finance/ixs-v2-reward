// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRewardSugar {
    /*
     * @notice Get the earned fees for a specific gauge and tokenId
     * @param _gauge The address of the gauge
     * @param _tokenId The lock Id of the user
     * @return tokens The addresses of the tokens in the pool
     * @return rewards The amounts of the tokens earned
     */
    function getFeeVotingRewards(
        address _gauge,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint256[] memory rewards);

    /*
     * @notice Get the earned bribes for a specific gauge and tokenId
     * @param _gauge The address of the gauge
     * @param _tokenId The lock Id of the user
     * @return tokens The addresses of the tokens in the pool
     * @return rewards The amounts of the tokens earned
     */
    function getBribeVotingRewards(
        address _gauge,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint256[] memory rewards);

    /*
     * @notice Get the earned fees and bribes for a specific gauge and tokenId
     * @param _gauge The address of the gauge
     * @param _tokenId The lock Id of the user
     * @return tokens The addresses of the tokens in the pool
     * @return fees The amounts of the fees earned
     * @return bribes The amounts of the bribes earned
     */
    function getFeeAndBribeVotingRewards(
        address _gauge,
        uint256 _tokenId
    ) external view returns (address[] memory tokens, uint256[] memory fees, uint256[] memory bribes);

    /*
     * @notice Get the earned fees and bribes for multiple gauges and tokenId
     * @param _gauges The addresses of the gauges
     * @param _tokenId The lock Id of the user
     * @return tokens The addresses of the tokens in the pool
     * @return fees The amounts of the fees earned
     * @return bribes The amounts of the bribes earned
     */
    function getFeeAndBribeVotingRewardsForOneTokenIdAndMultipleGauges(
        address[] calldata _gauges,
        uint256 _tokenId
    ) external view returns (address[][] memory tokens, uint256[][] memory fees, uint256[][] memory bribes);
}