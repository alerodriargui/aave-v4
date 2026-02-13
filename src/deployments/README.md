# Aave V4 Deployment Infrastructure

Infrastructure for deploying and configuring the Aave V4 hub-and-spoke protocol.

## Deployment Order

A full Aave V4 deployment proceeds in this order:

```
1. LiquidationLogic library (external library, must be pre-deployed)
2. AccessManager + AccessManagerEnumerable          (AaveV4AccessBatch)
3. HubConfigurator + SpokeConfigurator              (AaveV4ConfiguratorBatch)
4. Configure selector→role mappings on AccessManager
5. Hub(s) + InterestRateStrategy + TreasurySpoke    (AaveV4HubBatch, per hub)
6. SpokeInstance(s) + AaveOracle                    (AaveV4SpokeInstanceBatch, per spoke)
7. Grant roles to all components
8. List assets on hub(s)                            (via HubConfigEngine or HubConfigurator)
9. Register spokes on hub(s)                        (via HubConfigEngine or HubConfigurator)
10. Configure reserves on spoke(s)                  (via SpokeConfigEngine or SpokeConfigurator)
11. Set liquidation config on spoke(s)
12. Deploy periphery (gateways)                     (AaveV4GatewayBatch)
13. Transfer admin roles to governance
```

### LiquidationLogic Pre-deployment

The `LiquidationLogic` library is an external library linked into `SpokeInstance`. It **must** be deployed before the spoke batch. The bytecode placeholder `__$a48140799943db40fec4e369e92a011fa5$__` appears 3 times in SpokeInstance and must be linked at deploy time.

In tests, `dynamic_test_linking = true` in `foundry.toml` handles this automatically.

For production deployments, run the pre-compile step first:

```bash
# Step 1: Deploy LiquidationLogic and set FOUNDRY_LIBRARIES in .env
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# Step 2: Run the main deploy script (Foundry auto-links via FOUNDRY_LIBRARIES)
forge script scripts/deploy/AaveV4FullDeploy.s.sol --broadcast --fork-url $RPC --ffi
```

The `LibraryPreCompile` script deploys LiquidationLogic via CREATE2 and writes the `FOUNDRY_LIBRARIES` env var to `.env`. This causes Foundry to link the library into SpokeInstance at compile time. The main deploy script verifies this was done before deploying spokes.

## Architecture

```
src/deployments/
├── batches/                    # Batch constructors — deploy related contracts together
│   ├── AaveV4AccessBatch       # → AccessManager, AccessManagerEnumerable
│   ├── AaveV4ConfiguratorBatch # → HubConfigurator, SpokeConfigurator
│   ├── AaveV4HubBatch          # → Hub, InterestRateStrategy, TreasurySpoke
│   ├── AaveV4SpokeInstanceBatch# → SpokeInstance (proxy), AaveOracle
│   └── AaveV4GatewayBatch      # → NativeTokenGateway, SignatureGateway
│
├── orchestration/              # High-level orchestrators
│   ├── AaveV4DeployOrchestration  # Main entry: deployAaveV4() — calls batches in order
│   └── AaveV4DeployBase           # Static deploy helpers for each batch
│
├── procedures/                 # Granular operations
│   ├── config/                 # Hub/Spoke configuration procedures
│   ├── deploy/                 # Individual contract deploy procedures
│   └── roles/                  # Role setup procedures per component
│
├── config-engine/              # Post-deploy configuration system (see config-engine/README.md)
│   ├── AaveV4HubConfigEngine   # Stateless engine for Hub config via HubConfigurator
│   ├── AaveV4SpokeConfigEngine # Stateless engine for Spoke config via SpokeConfigurator
│   ├── AaveV4PayloadBase       # Abstract base for governance payloads
│   ├── AaveV4HubPayload        # Abstract Hub payload with virtual hooks
│   └── AaveV4SpokePayload      # Abstract Spoke payload with virtual hooks
│
├── libraries/
│   ├── BatchReports            # Report structs for each batch
│   ├── OrchestrationReports    # Full deployment report aggregation
│   └── ConfigData              # Parameter structs for config operations
│
└── utils/
    ├── InputUtils              # Config JSON input parsing
    ├── Roles                   # Role ID constants (0–15)
    ├── Create2Utils            # Deterministic deployment helpers
    ├── Logger / MetadataLogger # Deployment logging and JSON output
    └── ISpokeInstance          # Spoke instance interface
```

## Configuration

### Config JSON Schema

Deployment configuration uses a unified JSON format. See `config/template.json` for the full schema.

Key sections:

| Section              | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `infrastructure`     | Admin addresses, salt, optional gateway/native wrapper addresses         |
| `defaults`           | 3-level fallback values for spoke, reserve, asset, tokenization settings |
| `tokens`             | Token registry — maps string keys to on-chain addresses and price feeds  |
| `hubs`               | Hub instances to deploy (by key)                                         |
| `spokes`             | Spoke instances to deploy (by key, with optional liquidation config)     |
| `assets`             | Assets to list on hubs (token key, hub key, IR data, tokenization)       |
| `spokeRegistrations` | Connect assets to spokes (supply/draw caps, risk premium)                |
| `reserves`           | Configure reserves on spokes (collateral params, borrowable, etc.)       |
| `periphery`          | Gateway deployment flags                                                 |

### Default Resolution

ConfigReader resolves values with 3-level priority:

1. **Per-item field** (e.g., `assets[0].liquidityFee`)
2. **Defaults section** (e.g., `defaults.asset.liquidityFee`)
3. **Hardcoded constant** (e.g., `DEFAULT_LIQUIDITY_FEE = 1000`)

### Roles (Roles.sol)

| ID  | Name                          | Used By                                     |
| --- | ----------------------------- | ------------------------------------------- |
| 0   | DEFAULT_ADMIN_ROLE            | AccessManager admin                         |
| 1   | HUB_ADMIN_ROLE                | Hub administrative functions                |
| 2   | SPOKE_ADMIN_ROLE              | Spoke administrative functions              |
| 3   | USER_POSITION_UPDATER_ROLE    | Position manager operations                 |
| 4   | HUB_FEE_MINTER_ROLE           | Hub fee minting                             |
| 5   | HUB_CONFIGURATOR_ROLE         | Hub functions called by HubConfigurator     |
| 6   | SPOKE_CONFIGURATOR_ROLE       | Spoke functions called by SpokeConfigurator |
| 7   | SPOKE_POSITION_UPDATER_ROLE   | Spoke position updates                      |
| 8   | DEFICIT_ELIMINATOR_ROLE       | Deficit elimination                         |
| 9   | HUB_CONFIGURATOR_ADMIN_ROLE   | HubConfigurator admin selectors             |
| 10  | HUB_HALT_ROLE                 | HubConfigurator halt selectors              |
| 11  | HUB_DEACTIVATE_ROLE           | HubConfigurator deactivate selectors        |
| 12  | HUB_CAPS_RESET_ROLE           | HubConfigurator caps reset selectors        |
| 13  | SPOKE_CONFIGURATOR_ADMIN_ROLE | SpokeConfigurator admin selectors           |
| 14  | SPOKE_FREEZE_ROLE             | SpokeConfigurator freeze selectors          |
| 15  | SPOKE_PAUSE_ROLE              | SpokeConfigurator pause selectors           |

## Running

### Batch Deployment (existing script)

```bash
# Uses config/AaveV4DeployInput.json
forge script scripts/deploy/AaveV4DeployBatch.s.sol --broadcast --rpc-url $RPC_URL
```

### Tests

```bash
# All deployment tests
forge test --match-path "tests/deployments/*" -vvv

# Config engine tests only
forge test --match-path "tests/deployments/config-engine/AaveV4ConfigEngine*" -vvv

# ConfigReader scenario tests
forge test --match-path "tests/deployments/config-engine/ConfigReader*" -vvv
```

### Test Scenarios

Test JSON configs are in `config/test/`. Each exercises a different deployment pattern:

| File                                     | Scenario                                             |
| ---------------------------------------- | ---------------------------------------------------- |
| `test-hub-spoke-2assets.json`            | Standard 2-asset deployment with full coverage       |
| `test-hub-spoke-no-tokenization.json`    | Tokenization disabled globally                       |
| `test-hub-spoke-mixed-tokenization.json` | Mixed: per-asset tokenization enable/disable/inherit |
| `test-2hubs-2spokes-cross-hub.json`      | 2 hubs, 2 spokes, cross-hub asset sharing            |
| `test-single-asset.json`                 | Minimal single-asset deployment                      |
| `test-hub-only-no-assets.json`           | Bare hub deploy, no assets or spokes                 |
| `test-spoke-reg-only.json`               | Add spoke to existing hub with listed assets         |
| `test-asset-listing-only.json`           | List new assets on existing hub, no spoke work       |
| `test-hub-2spokes-shared.json`           | 1 hub with 2 spokes sharing same liquidity pool      |
