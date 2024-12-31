// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.19;

import {IVelo} from "./interfaces/IVelo.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {IFunder} from "./interfaces/IFunder.sol";
/// @title Funder
/// @author IXS
/// @notice main funding contract for the IXS V2
/// @dev Emitted by the Minter
contract Funder is IFunder {
    address public velo;
    address private minter;

    constructor(address _velo) {
        minter = msg.sender;
        velo = _velo;
    }

    /// @dev No checks as its meant to be once off to set minting rights to BaseV1 Minter
    function setMinter(address _minter) external {
        if (msg.sender != minter) revert NotMinter();
        minter = _minter;
    }

    function withdraw(address account, uint256 amount) external returns (bool) {
        if (msg.sender != minter) revert NotMinter();
        if(IVelo(velo).balanceOf(address(this)) < amount) revert NotEnoughBalance();
        ERC20(velo).transfer(account, amount);
        return true;
    }
}
