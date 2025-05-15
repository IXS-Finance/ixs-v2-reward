pragma solidity 0.8.19;

contract MockVault {
    address public poolFeesCollector;
    mapping(bytes32 => address[]) public poolTokens;

    // address[] public poolTokens = new address[](2);

    constructor(address _poolFeesCollector) {
        // poolTokens[0] = address(1);
        // poolTokens[1] = address(2);
        poolFeesCollector = _poolFeesCollector;

    }
    
    function getPoolFeesCollector() external view returns (address) {
        return poolFeesCollector;
    }

    function getPoolTokens(bytes32 id) external view returns (address[] memory, uint256[] memory, uint256) {
        return (poolTokens[id], new uint256[](2), 0);
    }

    function setPoolTokens(address _pool, address[] memory _tokens) external {
        // do nothing
        bytes32 id = keccak256(abi.encodePacked(_pool));
        poolTokens[id] = _tokens;
    }
}