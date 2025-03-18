// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import "./BaseTest.sol";
import {IRewardsDistributor} from "contracts/RewardsDistributor.sol";

contract RewardsDistributorTest is BaseTest {
    event Mint(address indexed _sender, uint256 _weekly);
    event NotifyReward(address indexed sender, address indexed reward, uint256 amount);

    address nonTeam = address(0x2);
    address pendingTeam = address(0x3);
    uint256 initialEpochRewards = 15_000_000 * 1e18;

    function testSetTeamSuccess() public {
        minter.setTeam(pendingTeam);
        assertEq(minter.pendingTeam(), pendingTeam);
    }

    function testSetTeamRevertNotTeam() public {
        vm.prank(nonTeam);
        vm.expectRevert(IRewardsDistributor.NotTeam.selector);
        minter.setTeam(pendingTeam);
    }

    function testSetTeamRevertZeroAddress() public {
        vm.expectRevert(IRewardsDistributor.ZeroAddress.selector);
        minter.setTeam(address(0));
    }

    function testAcceptTeamSuccess() public {
        minter.setTeam(pendingTeam);
        vm.prank(pendingTeam);
        minter.acceptTeam();
        assertEq(minter.team(), pendingTeam);
    }

    function testAcceptTeamRevertNotPendingTeam() public {
        minter.setTeam(pendingTeam);
        vm.prank(nonTeam);
        vm.expectRevert(IRewardsDistributor.NotPendingTeam.selector);
        minter.acceptTeam();
    }

    function testUpdatePeriodSuccess() public {
        vm.warp(block.timestamp + 1 weeks); // Move forward in time
        uint256 epochRewards = 15_000_000 * 1e18;
        deal(address(VELO), address(minter), epochRewards);

        vm.expectEmit(true, true, false, true, address(voter));
        emit NotifyReward(address(minter), address(VELO), epochRewards);
        vm.expectEmit(true, false, false, true, address(minter));
        emit Mint(address(owner), epochRewards);
        minter.updatePeriod();
        assertEq(minter.activePeriod(), block.timestamp / 1 weeks * 1 weeks);
    }

    function testChangeEpochRewardsSuccess() public {
        uint256 newEpochRewards = 10_000_000 * 1e18;
        minter.changeEpochRewards(newEpochRewards);
        assertEq(minter.epochRewards(), newEpochRewards);
    }

    function testUpdatePeriodInsufficientBalance() public {
        // Move forward in time to ensure the period can be updated
        vm.warp(block.timestamp + 1 weeks);

        // Ensure the RewardsDistributor has zero balance of VELO
        uint256 epochRewards = 15_000_000 * 1e18;
        deal(address(VELO), address(minter), 0);

        // Expect the updatePeriod to fail due to insufficient balance
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        minter.updatePeriod();
    }

    function testUpdatePeriodNoChange() public {
        deal(address(VELO), address(minter), 0);
        uint256 initialActivePeriod = minter.activePeriod();
        minter.updatePeriod();
        assertEq(minter.activePeriod(), initialActivePeriod);
        // Deal some VELO tokens to the minter
        uint256 epochRewards = 15_000_000 * 1e18;
        deal(address(VELO), address(minter), epochRewards);

        // Record the initial balance of the minter
        uint256 initialBalance = VELO.balanceOf(address(minter));

        // Call updatePeriod
        minter.updatePeriod();

        // Assert that the balance of the minter remains unchanged
        uint256 finalBalance = VELO.balanceOf(address(minter));
        assertEq(initialBalance, finalBalance);
    }

    function testChangeEpochRewardsRevertNotTeam() public {
        uint256 newEpochRewards = 10_000_000 * 1e18;
        vm.prank(nonTeam);
        vm.expectRevert(IRewardsDistributor.NotTeam.selector);
        minter.changeEpochRewards(newEpochRewards);
    }
}