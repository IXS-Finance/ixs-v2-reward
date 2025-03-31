// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IRewardsDistributor} from "./interfaces/IRewardsDistributor.sol";
import {IIxs} from "./interfaces/IIxs.sol";
import {IVoter} from "./interfaces/IVoter.sol";
import {IVotingEscrow} from "./interfaces/IVotingEscrow.sol";
import {IEpochGovernor} from "./interfaces/IEpochGovernor.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {console} from "forge-std/console.sol";


/// @title RewardsDistributor
contract RewardsDistributor is IRewardsDistributor {
    using SafeERC20 for IIxs;

    IIxs public immutable ixs;

    IVoter public immutable voter;

    uint256 public constant EPOCH_DURATION = 2 weeks;

    uint256 public activePeriod;

    address public team;

    address public pendingTeam;

    uint256 public availableDeposit;

    uint256 public lastAvailableDeposit;

    constructor(
        address _voter // the voting & distribution system
    ) {
        voter = IVoter(_voter);
        IVotingEscrow IVe = IVotingEscrow(IVoter(_voter).ve());
        ixs = IIxs(IVe.token());
        team = msg.sender;
        activePeriod = ((block.timestamp) / EPOCH_DURATION) * EPOCH_DURATION; // allow emissions this coming epoch
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

    function updatePeriod() external returns (uint256 _period) {
        _period = activePeriod;
        if (block.timestamp >= _period + EPOCH_DURATION) {
            _period = (block.timestamp / EPOCH_DURATION) * EPOCH_DURATION;
            activePeriod = _period;
            if (availableDeposit == 0) {
                return 0;
            }

            ixs.approve(address(voter), availableDeposit);
            voter.notifyRewardAmount(availableDeposit);
            lastAvailableDeposit = availableDeposit;
            emit Mint(msg.sender, availableDeposit);
            availableDeposit = 0;
        }
    }

    function deposit(uint amount) external {
        if (msg.sender != team) revert NotTeam();
        if (amount == 0) revert ZeroAmount();
        ixs.safeTransferFrom(msg.sender, address(this), amount);
        availableDeposit += amount;
        emit Deposit(msg.sender, amount);
    }
}
