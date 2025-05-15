## Deploy Velodrome v2

Velodrome v2 deployment is a multi-step process.  Unlike testing, we cannot impersonate governance to submit transactions and must wait on the necessary protocol actions to complete setup.  This README goes through the necessary instructions to deploy the Velodrome v2 upgrade.

### Environment setup
1. Copy-pasta `.env.sample` into a new `.env` and set the environment variables. `PRIVATE_KEY_DEPLOY` is the private key to deploy all scripts.
2. Copy-pasta `script/constants/TEMPLATE.json` into a new file `script/constants/{CONSTANTS_FILENAME}`. For example, "Optimism.json" in the .env would be a file of `script/constants/Optimism.json`.  Set the variables in the new file.

3. Run tests to ensure deployment state is configured correctly:
```ml
forge init
forge build
forge test
```

*Note that this will create a `script/constants/output/{OUTPUT_FILENAME}` file with the contract addresses created in testing.  If you are using the same constants for multiple deployments (for example, deploying in a local fork and then in prod), you can rename `OUTPUT_FILENAME` to store the new contract addresses while using the same constants.

4. Ensure all v2 deployments are set properly. In project directory terminal:
```
source .env
```

### Deployment
- Note that if deploying to a chain other than Optimism/Optimism Goerli, if you have a different .env variable name used for `RPC_URL`, `SCAN_API_KEY` and `ETHERSCAN_VERIFIER_URL`, you will need to use the corresponding chain name by also updating `foundry.toml`.  For this example we're deploying onto Optimism.

1. Deploy Velodrome v2 Core
```
forge script script/DeployVelodromeV2.s.sol:DeployVelodromeV2 --broadcast --slow --rpc-url optimism --verify -vvvv --private-key $PRIVATE_KEY_DEPLOY
```
2. Deploy gauges with pool addresses
Add the list of pool address in the script/constants/{CONSTANTS_FILENAME}
```
"poolsV2": [
        "0x80986ebD35E604B77Cd4bD8a858F6B0d4c08cDDB",
        "pool 1 address",
        ...
    ]
```
Command to deploy
```
forge script script/BalancerDeployGaugesAndPoolsV2.s.sol:DeployGauges --broadcast --slow --rpc-url optimism --verify -vvvv --private-key $PRIVATE_KEY_DEPLOY
```