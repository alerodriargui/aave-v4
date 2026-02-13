# Aave V4 Deployment Infrastructure

Infrastructure for deploying and configuring the Aave V4 hub-and-spoke protocol.

## Deploy Scripts

Two deploy scripts share a common base and a single JSON config format (`config/template.json`):

```
InputUtils                         struct + _buildDeployInputs() + _etchCreate2Factory()
  |
  +-- AaveV4DeployBatchBaseScript  Script + ConfigReader + warnings/sanitize + deploy-only run()
        |
        +-- AaveV4DeployBatchScript          concrete, deploy-only (contracts + roles)
        |
        +-- AaveV4FullDeployScript           override run() with deploy + config phase
              |
              +-- AaveV4FullDeployDefaultScript  concrete (reads config/deploy.json)
```

### Deploy-Only Path (`AaveV4DeployBatchScript`)

Deploys all contracts and grants roles in a single orchestration call. No asset listing, spoke registration, or reserve configuration.

```
JSON --ConfigReader--> _buildDeployInputs() --> FullDeployInputs
                                                      |
                                 AaveV4DeployOrchestration.deployAaveV4(grantRoles=true)
                                                      |
                         +--------+----------+--------+--------+---------+
                         |        |          |        |        |         |
                       Access  Configurator  Hubs   Spokes  Gateways  Roles
                       Batch     Batch      (N)     (N)     Batch    (granted)
```

**When to use:** You only need the contracts deployed and roles assigned. Configuration (listing assets, registering spokes, configuring reserves) will be done later via governance payloads or separate transactions.

**Steps:**

```bash
# 1. Create config/deploy.json from config/template.json (fill in infrastructure section, hubs, spokes)
cp config/template.json config/deploy.json
# Edit config/deploy.json with your addresses and deployment parameters

# 2. If deploying spokes, pre-deploy LiquidationLogic
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# 3. Run deploy
forge script scripts/deploy/AaveV4DeployBatch.s.sol --broadcast --fork-url $RPC
```

**What happens:**

1. Reads `config/deploy.json` via ConfigReader
2. Builds `FullDeployInputs` (with per-spoke `maxUserReservesLimit` from JSON)
3. Warns about zero addresses, prompts user to confirm
4. Calls `AaveV4DeployOrchestration.deployAaveV4()` with `grantRoles=true`
5. Orchestration deploys all batches, sets up selector-role mappings, and grants admin roles
6. Transfers `DEFAULT_ADMIN_ROLE` to the final admin
7. Writes deployment report to `output/reports/deployments/`

### Full Deploy Path (`AaveV4FullDeployScript`)

Deploys contracts, then configures them (list assets, register spokes, configure reserves) in a single transaction. Follows the V3 pattern where the deployer gets temporary admin roles during configuration, then revokes them.

```
JSON --ConfigReader--> _buildDeployInputs() --> FullDeployInputs
                                                      |
                                 AaveV4DeployOrchestration.deployAaveV4(grantRoles=false)
                                                      |
                         +--------+----------+--------+--------+
                         |        |          |        |        |
                       Access  Configurator  Hubs   Spokes  Gateways
                       Batch     Batch      (N)     (N)     Batch
                                                      |
                                            (deployer keeps DEFAULT_ADMIN_ROLE)
                                                      |
                                 Grant configurator contract roles (5, 6)
                                 Grant deployer temp roles (9, 13, 14, 15)
                                                      |
                                 +--------------------+--------------------+
                                 |                    |                    |
                          List assets           Register spokes     Configure reserves
                          on hubs               on hubs             on spokes
                          (HubConfigurator)      (HubConfigurator)   (SpokeConfigurator)
                                                      |
                                 Revoke deployer temp roles (9, 13, 14, 15)
                                 Grant permanent admin roles
                                 Transfer DEFAULT_ADMIN_ROLE to final admin
```

**When to use:** You want a complete market deployment in one shot — contracts, configuration, and role handoff all in a single transaction.

**Steps:**

```bash
# 1. Create config/deploy.json with ALL sections filled in:
#    infrastructure, hubs, spokes, assets, spokeRegistrations, reserves
cp config/template.json config/deploy.json
# Edit config/deploy.json

# 2. If deploying spokes, pre-deploy LiquidationLogic
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# 3. Run full deploy
forge script scripts/deploy/AaveV4FullDeploy.s.sol:AaveV4FullDeployDefaultScript \
  --broadcast --fork-url $RPC
```

**What happens:**

1. Reads JSON, counts hubs/spokes/assets/spokeRegistrations/reserves
2. If config ops exist: deploys with `grantRoles=false` (deployer stays admin)
3. Grants structural roles (HubConfigurator->role 5, SpokeConfigurator->role 6)
4. Grants deployer temporary configurator admin roles (9, 13, 14, 15)
5. **Config phase** — deployer calls configurators directly:
   - Lists assets on hubs via `HubConfigurator`
   - Registers spokes on hubs via `HubConfigurator`
   - Configures reserves on spokes via `SpokeConfigurator`
6. Revokes deployer temporary roles
7. Grants permanent admin roles to addresses from config
8. Transfers `DEFAULT_ADMIN_ROLE` from deployer to final admin
9. Writes deployment report

If no config ops are defined (empty assets/spokeRegistrations/reserves arrays), falls back to the deploy-only behavior with `grantRoles=true`.

### Deploy Script Comparison

| Feature                 | DeployBatch (deploy-only)            | FullDeploy (deploy+config)  |
| ----------------------- | ------------------------------------ | --------------------------- |
| Contract deployment     | Yes                                  | Yes                         |
| Role grants             | In orchestration (`grantRoles=true`) | After config phase          |
| List assets on hubs     | No                                   | Yes (via HubConfigurator)   |
| Register spokes on hubs | No                                   | Yes (via HubConfigurator)   |
| Configure reserves      | No                                   | Yes (via SpokeConfigurator) |
| Deployer temp roles     | Not needed                           | Granted then revoked        |
| Warnings/user prompt    | Yes                                  | Inherited (can override)    |
| Config JSON required    | `infrastructure`, `hubs`, `spokes`   | All sections                |

## Deployment Order

A full Aave V4 deployment proceeds in this order:

```
1. LiquidationLogic library (external library, must be pre-deployed)
2. AccessManager + AccessManagerEnumerable          (AaveV4AccessBatch)
3. HubConfigurator + SpokeConfigurator              (AaveV4ConfiguratorBatch)
4. Configure selector->role mappings on AccessManager
5. Hub(s) + InterestRateStrategy + TreasurySpoke    (AaveV4HubBatch, per hub)
6. SpokeInstance(s) + AaveOracle                    (AaveV4SpokeInstanceBatch, per spoke)
7. Deploy periphery (gateways)                      (AaveV4GatewayBatch)
8. Grant roles
9. List assets on hub(s)                            (via HubConfigurator)
10. Register spokes on hub(s)                       (via HubConfigurator)
11. Configure reserves on spoke(s)                  (via SpokeConfigurator)
12. Set liquidation config on spoke(s)
13. Transfer admin roles to governance
```

Steps 1-8 are handled by the orchestration. Steps 8-13 can happen in-band (FullDeploy) or later (governance payloads).

### LiquidationLogic Pre-deployment

The `LiquidationLogic` library is an external library linked into `SpokeInstance`. It **must** be deployed before the spoke batch. The bytecode placeholder appears in SpokeInstance and must be linked at deploy time.

In tests, `dynamic_test_linking = true` in `foundry.toml` handles this automatically.

For production deployments, run the pre-compile step first:

```bash
# Step 1: Deploy LiquidationLogic and set FOUNDRY_LIBRARIES in .env
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# Step 2: Run the main deploy script (Foundry auto-links via FOUNDRY_LIBRARIES)
forge script scripts/deploy/AaveV4FullDeploy.s.sol --broadcast --fork-url $RPC --ffi
```

The `LibraryPreCompile` script deploys LiquidationLogic via CREATE2 and writes the `FOUNDRY_LIBRARIES` env var to `.env`. This causes Foundry to link the library into SpokeInstance at compile time. The main deploy script verifies this was done before deploying spokes.

## Post-Deployment: Config Engine & Governance Payloads

After initial deployment, ongoing configuration changes go through the **config engine + payload** pattern (same as V3):

```
Governance / Timelock
       |
       | calls execute()
       v
  AaveV4Payload                             <-- per-proposal contract
       |
       | delegates to engines
       v
  AaveV4HubConfigEngine / SpokeConfigEngine <-- stateless libraries
       |
       | calls configurator
       v
  HubConfigurator / SpokeConfigurator       <-- AccessManaged
       |
       v
  Hub / Spoke                               <-- protocol contracts
```

The config engine is a **stateless library** that routes calls through the configurator contracts. Governance payloads inherit from `AaveV4HubPayload` or `AaveV4SpokePayload` and override virtual hooks to define what changes to make. When `execute()` is called, the payload base invokes the config engine with data from the hooks. The config engine needs the caller to have the appropriate roles on AccessManager.

### AaveV4HubConfigEngine

Stateless engine for Hub-side configuration. All calls route through `HubConfigurator`.

**Initial listing:**

- `listAssets(AssetListing[])` — Add new assets (token, IR strategy, fee receiver, IR data, liquidity fee)
- `addSpokes(SpokeListing[])` — Register spokes on hub for specific assets (with optional TokenizationSpoke via CREATE2)

**Granular updates:**

- `updateAssetLiquidityFees(AssetLiquidityFeeUpdate[])` — Update per-asset liquidity fees
- `updateAssetIRData(AssetIRDataUpdate[])` — Update interest rate parameters
- `updateAssetIRStrategies(AssetIRStrategyUpdate[])` — Swap IR strategy contracts
- `updateAssetFeeReceivers(AssetFeeReceiverUpdate[])` — Change fee receiver addresses
- `updateReinvestmentControllers(ReinvestmentControllerUpdate[])` — Update reinvestment controllers
- `updateSpokeCaps(SpokeCapUpdate[])` — Update spoke supply/draw caps
- `updateSpokeActive(SpokeActiveUpdate[])` — Activate/deactivate spokes
- `updateSpokeHalted(SpokeHaltedUpdate[])` — Halt/unhalt spokes
- `updateSpokeRiskPremiumThresholds(SpokeRiskPremiumUpdate[])` — Update risk premium thresholds

### AaveV4SpokeConfigEngine

Stateless engine for Spoke-side configuration. All calls route through `SpokeConfigurator`.

- `listReserves(ReserveListing[])` — Add new reserves (price source, collateral config, dynamic config)
- `updateLiquidationConfig(LiquidationConfigInput)` — Update spoke-wide liquidation parameters
- `updateReserves(ReserveConfigUpdate[])` — Update reserve static config (collateral, borrowable, frozen, paused)
- `updateDynamicConfigs(DynamicConfigUpdate[])` — Update reserve dynamic config (liquidation bonus, fee)

### Config Engine Role Requirements

**HubConfigEngine** requires:

- `HUB_CONFIGURATOR_ADMIN_ROLE` (9) — for all listing and update operations

**SpokeConfigEngine** requires:

- `SPOKE_CONFIGURATOR_ADMIN_ROLE` (13) — for listing and admin-level reserve updates
- `SPOKE_FREEZE_ROLE` (14) — for `updateFrozen` on reserves
- `SPOKE_PAUSE_ROLE` (15) — for `updatePaused` on reserves

### Governance Payloads

`AaveV4Payload` is a unified abstract contract for creating governance proposals that can include both hub and spoke operations. It extends `AaveV4PayloadBase` (`execute()` → `_preExecute()` → `_executePayload()` → `_postExecute()`).

Hub operations execute first, then spoke operations. Override only the hooks you need — unused hooks return empty arrays and are skipped.

```solidity
contract MyProposal is AaveV4Payload {
  constructor() AaveV4Payload(
    HUB_CONFIG_ENGINE, SPOKE_CONFIG_ENGINE,
    HUB, HUB_CONFIGURATOR, SPOKE, SPOKE_CONFIGURATOR, SALT
  ) {}

  // Hub hooks (override what you need)
  function newAssetListings() public pure override returns (AssetListing[] memory) { ... }
  function newSpokeListings() public pure override returns (SpokeListing[] memory) { ... }
  function spokeCapUpdates() public pure override returns (SpokeCapUpdate[] memory) { ... }

  // Spoke hooks (override what you need)
  function newReserveListings() public pure override returns (ReserveListing[] memory) { ... }
  function liquidationConfig() public pure override returns (LiquidationConfigInput memory) { ... }
  function reserveConfigUpdates() public pure override returns (ReserveConfigUpdate[] memory) { ... }
}
```

### Deploy Scripts vs Config Engine

| Concern       | Deploy Scripts (initial)  | Config Engine (ongoing)        |
| ------------- | ------------------------- | ------------------------------ |
| When          | Initial market deployment | Post-deployment changes        |
| Who           | Deployer EOA              | Governance / Timelock          |
| How           | Direct configurator calls | Via payload + engine           |
| Roles         | Deployer gets temp roles  | Governance has permanent roles |
| Config format | JSON (ConfigReader)       | Solidity (payload hooks)       |

## Architecture

```
scripts/deploy/
  AaveV4DeployBatchBase.s.sol     Base: ConfigReader + warnings + deploy-only run()
  AaveV4DeployBatch.s.sol         Concrete deploy-only script
  AaveV4FullDeploy.s.sol          Deploy + config in one shot
  helpers/
    DeployHelpersBase.sol          Shared imports and spoke/hub resolution
    AaveV4HubDeployHelper.sol      Hub config: list assets, register spokes
    AaveV4SpokeDeployHelper.sol    Spoke config: configure reserves, liquidation

src/deployments/
  batches/                    Batch constructors -- deploy related contracts together
    AaveV4AccessBatch           AccessManager, AccessManagerEnumerable
    AaveV4ConfiguratorBatch     HubConfigurator, SpokeConfigurator
    AaveV4HubBatch              Hub, InterestRateStrategy, TreasurySpoke
    AaveV4SpokeInstanceBatch    SpokeInstance (proxy), AaveOracle
    AaveV4GatewayBatch          NativeTokenGateway, SignatureGateway

  orchestration/              High-level orchestrators
    AaveV4DeployOrchestration   Main entry: deployAaveV4() -- calls batches in order
    AaveV4DeployBase            Static deploy helpers for each batch

  procedures/                 Granular operations
    config/                   Hub/Spoke configuration procedures
    deploy/                   Individual contract deploy procedures
    roles/                    Role setup procedures per component

  config-engine/              Post-deploy configuration system
    AaveV4HubConfigEngine     Stateless engine for Hub config via HubConfigurator
    AaveV4SpokeConfigEngine   Stateless engine for Spoke config via SpokeConfigurator
    AaveV4PayloadBase         Abstract base with execute() entry point
    AaveV4Payload             Unified payload with hub + spoke hooks

  libraries/
    BatchReports              Report structs for each batch
    OrchestrationReports      Full deployment report aggregation
    ConfigData                Parameter structs for config operations

  utils/
    InputUtils                FullDeployInputs struct + _buildDeployInputs()
    Roles                     Role ID constants (0-15)
    Create2Utils              Deterministic deployment helpers
    Logger / MetadataLogger   Deployment logging and JSON output
```

## Configuration

### Config JSON Format

All deploy scripts use the unified ConfigReader JSON format. See `config/template.json` for the full schema.

| Section              | Purpose                                                                  |
| -------------------- | ------------------------------------------------------------------------ |
| `infrastructure`     | Admin addresses, salt, optional gateway/native wrapper addresses         |
| `defaults`           | 3-level fallback values for spoke, reserve, asset, tokenization settings |
| `tokens`             | Token registry -- maps string keys to on-chain addresses and price feeds |
| `hubs`               | Hub instances to deploy (by key)                                         |
| `spokes`             | Spoke instances to deploy (by key, with optional liquidation config)     |
| `assets`             | Assets to list on hubs (token key, hub key, IR data, tokenization)       |
| `spokeRegistrations` | Connect assets to spokes (supply/draw caps, risk premium)                |
| `reserves`           | Configure reserves on spokes (collateral params, borrowable, etc.)       |
| `periphery`          | Gateway deployment flags                                                 |

### Default Resolution

ConfigReader (`scripts/ConfigReader.sol`) resolves all configurable values with 3-level priority:

1. **Per-item field** (e.g., `assets[0].liquidityFee`)
2. **Defaults section** (e.g., `defaults.asset.liquidityFee`)
3. **Hardcoded constant** (e.g., `DEFAULT_LIQUIDITY_FEE = 1000`)

Each reader has a `*Strict` variant that reverts instead of falling back to defaults.

### ConfigReader Functions

| Function                   | Returns                    | Reads From                     |
| -------------------------- | -------------------------- | ------------------------------ |
| `readInfrastructure()`     | `InfrastructureConfig`     | `.infrastructure`              |
| `readAsset(i)`             | `AssetConfig`              | `.assets[i]`                   |
| `readSpoke(i)`             | `SpokeDeployConfig`        | `.spokes[i]`                   |
| `readSpokeReg(i)`          | `SpokeRegConfig`           | `.spokeRegistrations[i]`       |
| `readReserve(i)`           | `ReserveConfig`            | `.reserves[i]`                 |
| `readLiquidationConfig(i)` | `ISpoke.LiquidationConfig` | `.spokes[i].liquidationConfig` |
| `tokenKeys()`              | `string[]`                 | `.tokens` keys                 |
| `tokenAddress(key)`        | `address`                  | `.tokens.<key>.address`        |
| `tokenPriceFeed(key)`      | `address`                  | `.tokens.<key>.priceFeed`      |

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

## Data Flow

```
config/deploy.json
       |
       v
  ConfigReader                   (parses JSON, resolves defaults)
       |
       v
  InputUtils._buildDeployInputs()
       |
       v
  FullDeployInputs               (transport struct: addresses, labels, per-spoke config, salt)
       |
       v
  AaveV4DeployOrchestration.deployAaveV4()
       |
       +-- deployAccessBatch()         --> AccessManager
       +-- deployConfiguratorBatch()   --> HubConfigurator, SpokeConfigurator
       +-- setupConfiguratorRoles()    --> selector->role mappings
       +-- deployHubs(hubLabels)       --> Hub[], IRStrategy[], TreasurySpoke[]
       +-- deploySpokes(spokeLabels, spokeMaxReservesLimits)
       |                               --> SpokeProxy[], AaveOracle[]
       +-- deployGateways()            --> NativeTokenGateway, SignatureGateway
       +-- grantRoles() (if enabled)   --> admin role grants + DEFAULT_ADMIN transfer
       |
       v
  FullDeploymentReport            (all deployed addresses)
```
