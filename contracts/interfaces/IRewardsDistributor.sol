// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IVelo} from "./IVelo.sol";
import {IVoter} from "./IVoter.sol";
import {IVotingEscrow} from "./IVotingEscrow.sol";
import {IRewardsDistributor} from "./IRewardsDistributor.sol";

interface IRewardsDistributor {
    event Mint(address indexed _sender, uint256 _weekly);
    event AcceptTeam(address indexed _newTeam);
    event ChangeWeekly(uint256 oldWeekly, uint256 newWeekly);

    error NotTeam();
    error ZeroAddress();
    error NotPendingTeam();

    /// @notice Duration of epoch in seconds
    function WEEK() external view returns (uint256);

    /// @notice Starting weekly emission of 15M VELO (VELO has 18 decimals)
    function weeklyRewards() external view returns (uint256);

    /// @notice Timestamp of start of epoch that updatePeriod was last called in
    function activePeriod() external returns (uint256);

    /// @notice Current team address in charge of emissions
    function team() external view returns (address);

    /// @notice Possible team address pending approval of current team
    function pendingTeam() external view returns (address);

    /// @notice Creates a request to change the current team's address
    /// @param _team Address of the new team to be chosen
    function setTeam(address _team) external;

    /// @notice Accepts the request to replace the current team's address
    ///         with the requested one, present on variable pendingTeam
    function acceptTeam() external;

    /// @notice Processes emissions and rebases. Callable once per epoch (1 week).
    /// @return _period Start of current epoch.
    function updatePeriod() external returns (uint256 _period);

    /// @notice change weekly emission
    function changeWeekly(uint256 _newWeekly) external;

}
