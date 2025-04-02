// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IReward} from "../interfaces/IReward.sol";
import {IGauge} from "../interfaces/IGauge.sol";
import {IPool} from "../interfaces/IPool.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {IVotingEscrow} from "../interfaces/IVotingEscrow.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC2771Context} from "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {VelodromeTimeLibrary} from "../libraries/VelodromeTimeLibrary.sol";
import {IPoolFees} from "../interfaces/IPoolFees.sol";
import {IBalancerPool} from "../interfaces/IBalancerPool.sol";
import {IVault} from "../interfaces/IVault.sol";

/// @title Velodrome V2 Gauge
/// @author veldorome.finance, @figs999, @pegahcarter
/// @notice Gauge contract for distribution of emissions by address
contract Gauge is IGauge, ERC2771Context, ReentrancyGuard {
    using SafeERC20 for IERC20;
    /// @inheritdoc IGauge
    address public immutable stakingToken;
    /// @inheritdoc IGauge
    address public immutable rewardToken;
    /// @inheritdoc IGauge
    address public immutable feesVotingReward;
    /// @inheritdoc IGauge
    address public immutable voter;
    /// @inheritdoc IGauge
    address public immutable team;

    /// @inheritdoc IGauge
    bool public immutable isPool;

    // uint256 internal constant DURATION = 7 days; // rewards are released over 7 days
    uint256 internal constant DURATION = 2 days; // rewards are released over 2 days
    uint256 internal constant PRECISION = 10 ** 18;

    /// @inheritdoc IGauge
    uint256 public periodFinish;
    /// @inheritdoc IGauge
    uint256 public rewardRate;
    /// @inheritdoc IGauge
    uint256 public lastUpdateTime;
    /// @inheritdoc IGauge
    uint256 public rewardPerTokenStored;
    /// @inheritdoc IGauge
    uint256 public totalSupply;
    /// @inheritdoc IGauge
    mapping(address => uint256) public balanceOf;
    /// @inheritdoc IGauge
    mapping(address => uint256) public userRewardPerTokenPaid;
    /// @inheritdoc IGauge
    mapping(address => uint256) public rewards;
    /// @inheritdoc IGauge
    mapping(uint256 => uint256) public rewardRateByEpoch;

    // uint256 public fees0;
    // uint256 public fees1;
    address public poolFees;

    // uint256 public feeForVe;
    uint256 internal constant BASIC_POINT = 1e4;

    mapping(address => mapping(address => uint256)) public supplyIndex;
    mapping(address => mapping(address => uint256)) public claimable;
    mapping(address => uint256) internal indexRatio;

    constructor(
        address _forwarder,
        address _stakingToken,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        bool _isPool,
        address _poolFees
    ) ERC2771Context(_forwarder) {
        stakingToken = _stakingToken;
        feesVotingReward = _feesVotingReward;
        rewardToken = _rewardToken;
        voter = _voter;
        isPool = _isPool;
        team = IVotingEscrow(IVoter(voter).ve()).team();
        poolFees = _poolFees;
    }

    function _claimFees() internal {
        if (!isPool) {
            return;
        }
        address[] memory tokens;
        uint256[] memory claimableAmounts;
        bytes32 _poolId = IBalancerPool(stakingToken).getPoolId();
        (tokens, claimableAmounts) = IPoolFees(poolFees).claimPoolTokensFees(_poolId, address(this));
        uint feeForVe = IVoter(voter).feeForVe();
        for(uint256 i = 0; i < tokens.length; i++) {
            IERC20 token = IERC20(tokens[i]);
            uint256 claimableAmount = claimableAmounts[i];
            if (claimableAmount > 0) {
                uint _share = (claimableAmount * feeForVe) / BASIC_POINT;
                uint remain = claimableAmount - _share;
                token.safeApprove(feesVotingReward, _share);
                IReward(feesVotingReward).notifyRewardAmount(address(token), _share);
                _updateRatio(tokens[i], remain);
                emit ClaimPoolFees(_msgSender(), address(token), _share);
            }
        }
    }

    /// @inheritdoc IGauge
    function rewardPerToken() public view returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            ((lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * PRECISION) /
            totalSupply;
    }

    /// @inheritdoc IGauge
    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    /// @inheritdoc IGauge
    function getReward(address _account) external nonReentrant {
        address sender = _msgSender();
        if (sender != _account && sender != voter) revert NotAuthorized();

        _updateRewards(_account);

        uint256 reward = rewards[_account];
        if (reward > 0) {
            rewards[_account] = 0;
            IERC20(rewardToken).safeTransfer(_account, reward);
            emit ClaimRewards(_account, reward);
        }

        //claim trading fees
        address _vault = IPoolFees(poolFees).vault();
        IERC20[] memory tokens;
        bytes32 _poolId = IBalancerPool(stakingToken).getPoolId();
        if(_poolId == bytes32(0)) return;
        (tokens, , ) = IVault(_vault).getPoolTokens(_poolId);
        for(uint256 i = 0; i < tokens.length; i++) {
            _updateSupplyIndex(_account, address(tokens[i]));
            IERC20 token = tokens[i];
            uint256 claimableAmount = claimable[msg.sender][address(token)];
            if (claimableAmount > 0) {
                claimable[msg.sender][address(token)] = 0;
                token.safeTransfer(_account, claimableAmount);
                emit ClaimTradingFees(address(token), _account, claimableAmount);
            }
        }
    }

    /// @inheritdoc IGauge
    function earned(address _account) public view returns (uint256) {
        return
            (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) /
            PRECISION +
            rewards[_account];
    }

    /// @inheritdoc IGauge
    function deposit(uint256 _amount) external {
        _depositFor(_amount, _msgSender());
    }

    /// @inheritdoc IGauge
    function deposit(uint256 _amount, address _recipient) external {
        _depositFor(_amount, _recipient);
    }

    function _depositFor(uint256 _amount, address _recipient) internal nonReentrant {
        if (_amount == 0) revert ZeroAmount();
        if (!IVoter(voter).isAlive(address(this))) revert NotAlive();

        address sender = _msgSender();
        _updateRewards(_recipient);

        IERC20(stakingToken).safeTransferFrom(sender, address(this), _amount);
        totalSupply += _amount;
        balanceOf[_recipient] += _amount;

        emit Deposit(sender, _recipient, _amount);
    }

    /// @inheritdoc IGauge
    function withdraw(uint256 _amount) external nonReentrant {
        address sender = _msgSender();

        _updateRewards(sender);

        totalSupply -= _amount;
        balanceOf[sender] -= _amount;
        IERC20(stakingToken).safeTransfer(sender, _amount);

        emit Withdraw(sender, _amount);
    }

    function _updateRewards(address _account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;
    }

    /// @inheritdoc IGauge
    function left() external view returns (uint256) {
        if (block.timestamp >= periodFinish) return 0;
        uint256 _remaining = periodFinish - block.timestamp;
        return _remaining * rewardRate;
    }

    /// @inheritdoc IGauge
    function notifyRewardAmount(uint256 _amount) external nonReentrant {
        address sender = _msgSender();
        if (sender != voter) revert NotVoter();
        if (_amount == 0) revert ZeroAmount();
        _claimFees();
        _notifyRewardAmount(sender, _amount);
    }

    /// @inheritdoc IGauge
    function notifyRewardWithoutClaim(uint256 _amount) external nonReentrant {
        address sender = _msgSender();
        if (sender != team) revert NotTeam();
        if (_amount == 0) revert ZeroAmount();
        _notifyRewardAmount(sender, _amount);
    }
    function _notifyRewardAmount(address sender, uint256 _amount) internal {
        rewardPerTokenStored = rewardPerToken();
        uint256 timestamp = block.timestamp;
        uint256 currentPeriod = IVoter(voter).vestingPeriod();
        uint256 timeUntilNext = VelodromeTimeLibrary.periodNext(timestamp, currentPeriod) - timestamp;

        if (timestamp >= periodFinish) {
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = _amount / timeUntilNext;
        } else {
            uint256 _remaining = periodFinish - timestamp;
            uint256 _leftover = _remaining * rewardRate;
            IERC20(rewardToken).safeTransferFrom(sender, address(this), _amount);
            rewardRate = (_amount + _leftover) / timeUntilNext;
        }
        if (rewardRate == 0) revert ZeroRewardRate();
        rewardRateByEpoch[VelodromeTimeLibrary.periodStart(timestamp, currentPeriod)] = rewardRate;

        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = IERC20(rewardToken).balanceOf(address(this));
        if (rewardRate > balance / timeUntilNext) revert RewardRateTooHigh();

        lastUpdateTime = timestamp;
        periodFinish = timestamp + timeUntilNext;
        emit NotifyReward(sender, _amount);
    }

    function _updateSupplyIndex(
        address _recipient,
        address _token
    ) internal {
        uint256 _supplied = balanceOf[_recipient]; // get LP balance of `recipient`
        uint256 _indexRatio = indexRatio[_token]; // get global index for accumulated fees

        if (_supplied > 0) {
            uint256 _supplyIndex = supplyIndex[_recipient][_token]; // get last adjusted index for _recipient
            uint256 _index = _indexRatio; // get global index for accumulated fees
            supplyIndex[_recipient][_token] = _index; // update user current position to global position
            uint256 _delta0 = _index - _supplyIndex; // see if there is any difference that need to be accrued
            if (_delta0 > 0) {
                uint256 _share = (_supplied * _delta0) / 1e30; // add accrued difference for each supplied token
                claimable[_recipient][_token] += _share;
            }
        } else {
            supplyIndex[_recipient][_token] = _indexRatio;
        }
    }

    /**
     * @dev update index ratio after each swap
     * @param _token tokenIn address
     * @param _feeAmount swapping fee
     */
    function _updateRatio(
        address _token,
        uint256 _feeAmount
    ) internal {
        // Only update on this pool if there is a fee
        if (_feeAmount == 0) return;
        uint256 _ratio = (_feeAmount * 1e30) / IERC20(stakingToken).totalSupply(); // 1e30 adjustment is removed during claim
        if (_ratio > 0) {
            indexRatio[_token] += _ratio;
        }
        emit UpdateRatio(_token, _feeAmount);
    }

    function getIndexRatio(address _token) external view returns (uint256) {
        return indexRatio[_token];
    }

}
