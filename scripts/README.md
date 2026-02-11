# Aave V4 Deployment Scripts

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil, cast)
- [Bun](https://bun.sh/) (for config validation)

## Quick Start (Local Anvil)

```bash
# 1. Start a local node
anvil

# 2. Deploy LiquidationLogic library (required before main deploy)
forge script scripts/LibraryPreCompile.s.sol \
  --broadcast \
  --rpc-url http://127.0.0.1:8545 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked
  --offline

# 3. Run the full deployment
forge script scripts/Script.s.sol:Deploy \
  --broadcast \
  --rpc-url http://127.0.0.1:8545 \
  -s "run()" \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked
  --offline
```

Deployed addresses are written to `output/deploy.json`.

## Configuration

All deployment parameters live in a JSON config file. Default path: `config/mainnet.json`. Override with `CONFIG_PATH` env var:

```bash
CONFIG_PATH=config/testnet.json forge script scripts/Script.s.sol:Deploy ...
```

### Validate Config Before Deploying

```bash
bun scripts/validate-config.js config/mainnet.json
```

Checks referential integrity (all keys resolve), constraint violations (collateral factor, liquidation bonus bounds), and prints warnings for suspicious configurations.

## Entry Points

| Command                     | Purpose                                                                                                                                         |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `-s "run()"`                | Full fresh deployment: AccessManager, spokes, hubs, assets, spoke registrations, roles, reserves, liquidation configs, periphery, configurators |
| `-s "deployConfigurator()"` | Load existing deployment from `output/deploy.json`, deploy HubConfigurator + SpokeConfigurator with full role setup                             |
| `-s "debug()"`              | Load existing deployment, run ad-hoc operations (edit function body as needed)                                                                  |
| `-s "seed()"`               | Load existing deployment, execute supply/borrow/repay operations for testing                                                                    |

### Example: Deploy Configurators on an Existing Deployment

```bash
forge script scripts/Script.s.sol:Deploy \
  --broadcast \
  --rpc-url http://127.0.0.1:8545 \
  -s "deployConfigurator()" \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked
```

## Library Pre-Compilation

`SpokeInstance` depends on `LiquidationLogic` as an external library. Forge cannot link it automatically in script mode. The two-step process:

1. `LibraryPreCompile.s.sol` deploys `LiquidationLogic` via CREATE2 and writes `FOUNDRY_LIBRARIES` to `.env`
2. The main script reads `.env` and Forge links the library at compile time

If you see `"no bytecode for contract; is it abstract or unlinked?"`, you need to run LibraryPreCompile first.

If switching chains, LibraryPreCompile will detect a stale `FOUNDRY_LIBRARIES` value and ask you to re-run.

## Output

`output/deploy.json` contains all deployed addresses:

```
admin, accessManager, hub.{KEY}, irStrategy.{KEY}, treasury.{KEY},
spoke.{KEY}, oracle.{KEY}, token.{KEY}, signatureGateway,
nativeTokenGateway, hubConfigurator, spokeConfigurator, commit
```

The `load()` function reads this file to restore state for `debug()`, `seed()`, and `deployConfigurator()`.

## Access Control

The deployment script sets up an AccessManager with the following role structure:

| Role                  | ID  | Purpose                                                                      |
| --------------------- | --- | ---------------------------------------------------------------------------- |
| DEFAULT_ADMIN         | 0   | Admin/deployer, can manage all roles                                         |
| HUB_ADMIN             | 1   | Can call restricted Hub functions. Granted to deployer + HubConfigurator     |
| SPOKE_ADMIN           | 2   | Can call restricted Spoke functions. Granted to deployer + SpokeConfigurator |
| USER_POSITION_UPDATER | 3   | Can update user dynamic config and risk premiums                             |
| HUB_CONFIGURATOR      | 4   | Can call HubConfigurator functions. Grant to governance post-deploy          |
| SPOKE_CONFIGURATOR    | 5   | Can call SpokeConfigurator functions. Grant to governance post-deploy        |
| DEFICIT_ELIMINATOR    | 6   | Can call eliminateDeficit on Hub                                             |

Post-deployment, grant `HUB_CONFIGURATOR_ROLE` and `SPOKE_CONFIGURATOR_ROLE` to your governance address or multisig.

## Post-Deployment Validation

After deploying, run `tests/DeployValidation.t.sol` to verify all on-chain state matches the source configuration. The test reads expected values from the config JSON (via `scripts/ConfigReader.sol`) and deployed addresses from `output/deploy.json` (via `tests/DeployReader.sol`).

```bash
# Against the same anvil used for deployment
forge test --match-contract DeployValidation --fork-url http://127.0.0.1:8545 -vvv

# Against a mainnet fork
forge test --match-contract DeployValidation --fork-url $RPC_MAINNET -vvv

# Custom config/deploy paths
CONFIG_PATH=config/testnet.json DEPLOY_PATH=output/deploy-testnet.json \
  forge test --match-contract DeployValidation --fork-url $RPC -vvv
```

The 13 tests cover:

- **Hub assets**: listings, decimals, feeReceiver, irStrategy, liquidityFee, IR parameters
- **Spoke registrations**: addCap, drawCap, riskPremiumThreshold, active, halted
- **Treasury auto-registration**: addCap=max, drawCap=0 on every hub asset
- **Reserves**: ReserveConfig, DynamicReserveConfig (collateralFactor, maxLiquidationBonus, liquidationFee)
- **Liquidation configs**: per-spoke targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor
- **Oracle setup**: spoke↔oracle linkage, decimals, per-reserve price sources, price > 0
- **Position managers**: gateways registered as active PMs on each spoke
- **Access control**: role grants, all Hub/Spoke/Configurator selector→role mappings
- **Tokenization spokes**: ERC4626 vault registration, ERC20 metadata, hub/assetId references
- **Authority chain**: all contracts point to the same AccessManager

| Environment Variable | Default               | Purpose                |
| -------------------- | --------------------- | ---------------------- |
| `CONFIG_PATH`        | `config/mainnet.json` | Expected configuration |
| `DEPLOY_PATH`        | `output/deploy.json`  | Deployed addresses     |

## Redeployment on Persistent Forks

Hubs and SpokeInstances use CREATE2. On a persistent fork (anvil without reset, Tenderly), the same inputs produce the same address. The script returns existing contracts rather than redeploying, which can cause `UnderlyingAlreadyListed` reverts if assets were already added.

Fix: reset the fork (`anvil` restart) or use different salt values.
