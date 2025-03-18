// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "./BaseTest.sol";
import {IVoter, Voter} from "contracts/Voter.sol";

contract VoterTest is BaseTest {
    address nonGovernor = address(0x2);
    address newDistributor = address(0x3);
    uint256 constant BASIC_POINT = 10000; // Example value, adjust as needed
    function testSetPeriodSuccess() public {
        uint256 newPeriod = 2 weeks;
        vm.prank(address(governor));
        voter.updateVestingPeriod(newPeriod);
        assertEq(voter.vestingPeriod(), newPeriod);
    }

    function testSetPeriodRevertNotGovernor() public {
        uint256 newPeriod = 2 weeks;
        vm.prank(nonGovernor);
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.updateVestingPeriod(newPeriod);
    }
    function testSetPeriodRevertInvalidPeriod() public {
        uint256 newPeriod = DURATION - 1;
        vm.prank(address(governor));
        vm.expectRevert(IVoter.InvalidPeriod.selector);
        voter.updateVestingPeriod(newPeriod);
    }
    function testSetMinterSuccess() public {
        vm.prank(address(governor));
        voter.setMinter(newDistributor);
        assertEq(voter.distributor(), newDistributor);
    }

    function testSetMinterRevertNotGovernor() public {
        vm.prank(address(nonGovernor));
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.setMinter(newDistributor);
    }

    function testChangeFeeForVeSuccess() public {
        uint256 newFee = 5000; // Example value less than BASIC_POINT
        vm.prank(address(governor));
        voter.changeFeeForVe(newFee);
        assertEq(voter.feeForVe(), newFee);
    }
    function testChangeFeeForVeRevertNotGovernor() public {
        uint256 newFee = 5000;
        vm.prank(nonGovernor);
        vm.expectRevert(IVoter.NotGovernor.selector);
        voter.changeFeeForVe(newFee);
    }
    function testChangeFeeForVeRevertInvalidFee() public {
        uint256 newFee = BASIC_POINT + 1;
        vm.prank(address(governor));
        vm.expectRevert(IVoter.InvalidFeeForVe.selector);
        voter.changeFeeForVe(newFee);
    }

}
