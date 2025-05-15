pragma solidity 0.8.19;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pool} from "../../contracts/Pool.sol";
contract MockPool is Pool{
    constructor() {}
    function getPoolId() external view returns (bytes32){
        // return bytes32(0xc89efdaa54c0f20c7adf612882df0950f5a951637e0307cdcb4c672f298b8bc6);
        return keccak256(abi.encodePacked(address(this)));

    }
   
}