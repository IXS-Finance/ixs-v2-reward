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
        vm.warp(block.timestamp + 2 weeks); // Move forward in time
        uint256 epochRewards = 15_000_000 * 1e18;
        // deal(address(VELO), address(minter), epochRewards);
        address _team = IRewardsDistributor(minter).team();
        deal(address(VELO), address(_team), epochRewards);
        vm.startPrank(_team);
        VELO.approve(address(minter), epochRewards);
        minter.deposit(epochRewards);
        vm.stopPrank();
        assertEq(minter.availableDeposit(), epochRewards);

        vm.expectEmit(true, true, false, true, address(voter));
        emit NotifyReward(address(minter), address(VELO), epochRewards);
        vm.expectEmit(true, false, false, true, address(minter));
        emit Mint(address(voter), epochRewards);
        vm.prank(address(voter));
        minter.updatePeriod();
        // assertEq(minter.activePeriod(), block.timestamp / 2 weeks * 2 weeks);
        assertEq(minter.availableDeposit(), 0);
        assertEq(minter.lastAvailableDeposit(), epochRewards);
    }

    function testUpdatePeriodNoChange() public {
        deal(address(VELO), address(minter), 0);
        // uint256 initialActivePeriod = minter.activePeriod();
        vm.prank(address(voter));
        minter.updatePeriod();
        // assertEq(minter.activePeriod(), initialActivePeriod);
        // Deal some VELO tokens to the minter
        uint256 epochRewards = 15_000_000 * 1e18;
        deal(address(VELO), address(minter), epochRewards);

        // Record the initial balance of the minter
        uint256 initialBalance = VELO.balanceOf(address(minter));

        // Call updatePeriod
        vm.prank(address(voter));
        minter.updatePeriod();

        // Assert that the balance of the minter remains unchanged
        uint256 finalBalance = VELO.balanceOf(address(minter));
        assertEq(initialBalance, finalBalance);
    }

    function testDepositSuccess() public {
        vm.startPrank(minter.team());
        uint256 epochRewards = 15_000_000 * 1e18;
        deal(address(VELO), address(minter.team()), epochRewards);
        VELO.approve(address(minter), epochRewards);
        minter.deposit(epochRewards);
        vm.stopPrank();
        assertEq(minter.availableDeposit(), epochRewards);
        assertEq(minter.lastAvailableDeposit(), 0);
        assertEq(VELO.balanceOf(address(minter)), epochRewards);
    }
    
    function testDepositRevertZeroAmount() public {
        vm.startPrank(minter.team());
        uint256 epochRewards = 0;
        deal(address(VELO), address(minter), epochRewards);
        VELO.approve(address(minter), epochRewards);
        vm.expectRevert(IRewardsDistributor.ZeroAmount.selector);
        minter.deposit(epochRewards);
    }

    function testMultipleUpdatePeriod() public {
        // vm.warp(block.timestamp + 2 weeks); // Move forward in time
        uint256 epochRewards = 15_000_000 * 1e18;
        // deal(address(VELO), address(minter), epochRewards);
        address _team = IRewardsDistributor(minter).team();
        deal(address(VELO), address(_team), 3 * epochRewards);
        vm.startPrank(_team);
        VELO.approve(address(minter), 3 * epochRewards);
        minter.deposit(epochRewards);
        vm.stopPrank();
        assertEq(minter.availableDeposit(), epochRewards);

        vm.expectEmit(true, true, false, true, address(voter));
        emit NotifyReward(address(minter), address(VELO), epochRewards);
        vm.expectEmit(true, false, false, true, address(minter));
        vm.prank(address(voter));
        emit Mint(address(voter), epochRewards);
        minter.updatePeriod();

        //second deposit
        vm.prank(_team);
        minter.deposit(epochRewards);
        assertEq(minter.availableDeposit(), epochRewards);
        vm.prank(address(voter));
        emit Mint(address(voter), epochRewards);
        minter.updatePeriod();
        assertEq(minter.availableDeposit(), 0);

        //third deposit
        vm.prank(_team);
        minter.deposit(epochRewards);
        assertEq(minter.availableDeposit(), epochRewards);
        vm.prank(address(voter));
        emit Mint(address(voter), epochRewards);
        minter.updatePeriod();
        assertEq(minter.availableDeposit(), 0);
    }
}