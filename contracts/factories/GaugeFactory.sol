// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IGaugeFactory} from "../interfaces/factories/IGaugeFactory.sol";
import {Gauge} from "../gauges/Gauge.sol";
import {IVault} from "../interfaces/IVault.sol";

contract GaugeFactory is IGaugeFactory {
    IVault public vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }
    function createGauge(
        address _forwarder,
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        bool isPool,
        uint256 _feeForVe
    ) external returns (address gauge) {
        address _poolFees = address(vault.getPoolFeesCollector());
        gauge = address(new Gauge(_forwarder, _pool, _feesVotingReward, _rewardToken, msg.sender, isPool, _poolFees, _feeForVe));
    }
}
