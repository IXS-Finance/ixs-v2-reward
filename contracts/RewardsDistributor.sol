// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IVelo} from "./interfaces/IVelo.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";


/// @title Minter
/// @author velodrome.finance, @figs999, @pegahcarter
/// @notice Controls minting of emissions and rebases for Velodrome
contract RewardsDistributor is IRewardsDistributor {
    using SafeERC20 for IVelo;

    IVelo public immutable ixs;

    IVoter public immutable voter;

    uint256 public constant WEEK = 1 weeks;

    IVotingEscrow public immutable ve;

    // uint256 public constant WEEKLY_DECAY = 9_900;

    // uint256 public constant MAXIMUM_TAIL_RATE = 100;

    // uint256 public constant MINIMUM_TAIL_RATE = 1;

    // uint256 public constant MAX_BPS = 10_000;

    // uint256 public constant NUDGE = 1;

    // uint256 public constant TAIL_START = 6_000_000 * 1e18;

    // uint256 public constant MAXIMUM_TEAM_RATE = 500;

    // uint256 public teamRate = 500; // team emissions start at 5%

    // uint256 public tailEmissionRate = 30;

    uint256 public weeklyRewards = 15_000_000 * 1e18;

    uint256 public activePeriod;

    // mapping(uint256 => bool) public proposals;

    address public team;

    address public pendingTeam;

    constructor(
        address _voter, // the voting & distribution system
        address _ve // the ve(3,3) system that will be locked into
    ) {
        ixs = IVelo(IVotingEscrow(_ve).token());
        voter = IVoter(_voter);
        ve = IVotingEscrow(_ve);
        team = msg.sender;
        activePeriod = ((block.timestamp) / WEEK) * WEEK; // allow emissions this coming epoch
    }


    function setTeam(address _team) external {
        if (msg.sender != team) revert NotTeam();
        if (_team == address(0)) revert ZeroAddress();
        pendingTeam = _team;
    }


    function acceptTeam() external {
        if (msg.sender != pendingTeam) revert NotPendingTeam();
        team = pendingTeam;
        delete pendingTeam;
        emit AcceptTeam(team);
    }

    // function nudge() external {
    //     address _epochGovernor = voter.epochGovernor();
    //     if (msg.sender != _epochGovernor) revert NotEpochGovernor();
    //     IEpochGovernor.ProposalState _state = IEpochGovernor(_epochGovernor).result();
    //     if (weekly >= TAIL_START) revert TailEmissionsInactive();
    //     uint256 _period = activePeriod;
    //     if (proposals[_period]) revert AlreadyNudged();
    //     uint256 _newRate = tailEmissionRate;
    //     uint256 _oldRate = _newRate;

    //     if (_state != IEpochGovernor.ProposalState.Expired) {
    //         if (_state == IEpochGovernor.ProposalState.Succeeded) {
    //             _newRate = _oldRate + NUDGE > MAXIMUM_TAIL_RATE ? MAXIMUM_TAIL_RATE : _oldRate + NUDGE;
    //         } else {
    //             _newRate = _oldRate - NUDGE < MINIMUM_TAIL_RATE ? MINIMUM_TAIL_RATE : _oldRate - NUDGE;
    //         }
    //         tailEmissionRate = _newRate;
    //     }
    //     proposals[_period] = true;
    //     emit Nudge(_period, _oldRate, _newRate);
    // }


    function updatePeriod() external returns (uint256 _period) {
        _period = activePeriod;
        if (block.timestamp >= _period + WEEK) {
            _period = (block.timestamp / WEEK) * WEEK;
            activePeriod = _period;
            uint256 _weeklyRewards = weeklyRewards;

            ixs.approve(address(voter), _weeklyRewards);
            voter.notifyRewardAmount(_weeklyRewards);

            emit Mint(msg.sender, _weeklyRewards);
        }
    }

    function changeWeekly(uint256 _newWeekly) external {
        if (msg.sender != team) revert NotTeam();
        emit ChangeWeekly(weeklyRewards, _newWeekly);
        weeklyRewards = _newWeekly;
    }
}
