// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


interface IFunder {
    error NotMinter();
    error NotEnoughBalance();
    /// @notice Mint an amount of tokens to an account
    ///         Only callable by Minter.sol
    /// @return True if success
    function withdraw(address account, uint256 amount) external returns (bool);

    /// @notice Address of Minter.sol
    function setMinter(address minter) external;
}
