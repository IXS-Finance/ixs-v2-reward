pragma solidity 0.8.19;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract MockPoolFees {
    address[] public tokens;
    address public vault;
    function claimPoolTokensFees(bytes32 _poolId, address recipient) external returns (address[] memory, uint256[] memory){
        uint[] memory amounts = new uint[](2);
        amounts[0] = 1e19;
        amounts[1] = 2e19;
        return (tokens, amounts);
    }

    function setTokens(address[] memory _tokens) external {
        // do nothing
        tokens = _tokens;
    }

    function setVault(address _vault) external {
        // do nothing
        vault = _vault;
    }

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }
   
}