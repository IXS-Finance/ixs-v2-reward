// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import "forge-std/StdJson.sol";
import "../test/Base_NotForTest.sol";

contract NotForTest_DeployVelodromeV2 is Base {
    using stdJson for string;
    string public basePath;
    string public path;

    uint256 public deployPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOY");
    address public deployerAddress = vm.addr(deployPrivateKey);
    string public constantsFilename = vm.envString("DEPLOYMENT_CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");
    string public jsonConstants;
    string public jsonOutput;

    // Vars to be set in each deploy script
    address feeManager;
    address team;
    address emergencyCouncil;

    constructor() {
        string memory root = vm.projectRoot();
        basePath = string.concat(root, "/script/constants/");

        // load constants
        path = string.concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);
        WETH = IWETH(abi.decode(vm.parseJson(jsonConstants, ".WETH"), (address)));
        allowedManager = abi.decode(vm.parseJson(jsonConstants, ".allowedManager"), (address));
        team = abi.decode(vm.parseJson(jsonConstants, ".team"), (address));
        feeManager = abi.decode(vm.parseJson(jsonConstants, ".feeManager"), (address));
        emergencyCouncil = abi.decode(vm.parseJson(jsonConstants, ".emergencyCouncil"), (address));
        vault = abi.decode(vm.parseJson(jsonConstants, ".vault"), (address));
        VELO = Velo(abi.decode(vm.parseJson(jsonConstants, ".VELO"), (address)));
        poolFactory = abi.decode(vm.parseJson(jsonConstants, ".PoolFactory"), (address));
    }

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
        deployGauge();
    }

    function _deploySetupBefore() public {
        // more constants loading - this needs to be done in-memory and not storage
        address[] memory _tokens = abi.decode(vm.parseJson(jsonConstants, ".whitelistTokens"), (address[]));
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
        }

        // Loading output and use output path to later save deployed contracts
        basePath = string.concat(basePath, "output/");
        path = string.concat(basePath, "DeployVelodromeV2-");
        path = string.concat(path, outputFilename);

        // start broadcasting transactions
        vm.startBroadcast(deployerAddress);

        tokens.push(address(VELO));
    }

    function _deploySetupAfter() public {
        // Set protocol state to team
        escrow.setTeam(team);
        minter.setTeam(team);
        // factory.setPauser(team);
        voter.setEmergencyCouncil(emergencyCouncil);
        voter.setEpochGovernor(team);
        voter.setGovernor(team);
        factoryRegistry.transferOwnership(team);

        // Set contract vars
        // factory.setFeeManager(feeManager);
        // factory.setVoter(address(voter));

        // finish broadcasting transactions
        vm.stopBroadcast();

        // write to file
        vm.writeJson(vm.serializeAddress("v2", "VELO", address(VELO)), path);
        vm.writeJson(vm.serializeAddress("v2", "VotingEscrow", address(escrow)), path);
        vm.writeJson(vm.serializeAddress("v2", "Forwarder", address(forwarder)), path);
        vm.writeJson(vm.serializeAddress("v2", "ArtProxy", address(artProxy)), path);
        vm.writeJson(vm.serializeAddress("v2", "Distributor", address(minter)), path);
        vm.writeJson(vm.serializeAddress("v2", "Voter", address(voter)), path);
        // vm.writeJson(vm.serializeAddress("v2", "Minter", address(distributor)), path);
        // vm.writeJson(vm.serializeAddress("v2", "PoolFactory", address(factory)), path);
        vm.writeJson(vm.serializeAddress("v2", "VotingRewardsFactory", address(votingRewardsFactory)), path);
        vm.writeJson(vm.serializeAddress("v2", "GaugeFactory", address(gaugeFactory)), path);
        vm.writeJson(vm.serializeAddress("v2", "ManagedRewardsFactory", address(managedRewardsFactory)), path);
        vm.writeJson(vm.serializeAddress("v2", "FactoryRegistry", address(factoryRegistry)), path);
        vm.writeJson(vm.serializeAddress("v2", "VeSugar", address(veSugar)), path);
    }
    function deployGauge() public {
        // Load pools from base-sepolia.json
        address[] memory _pools = abi.decode(vm.parseJson(jsonConstants, ".pools"), (address[]));

        // Start broadcasting transactions
        vm.startBroadcast(deployerAddress);

        // Create gauges for each pool
        for (uint256 i = 0; i < _pools.length; i++) {
            address gauge = IVoter(address(voter)).createGauge(address(poolFactory), _pools[i]);
            console.log("Created gauge for pool %s: %s", _pools[i], gauge);

            // Write gauge address to output file
            string memory gaugeKey = string.concat("Gauge-", vm.toString(_pools[i]));
            vm.writeJson(vm.serializeAddress("v2", gaugeKey, gauge), path);
        }

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }
}
