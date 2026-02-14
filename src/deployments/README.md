# Aave V4 Deployment Infrastructure

Infrastructure for deploying and configuring the Aave V4 hub-and-spoke protocol.

## Deployment & Configuration Flows

There are three paths for deploying and configuring Aave V4, depending on whether you need contracts only, contracts with initial configuration, or post-deployment changes via governance.

### Flow 1: Contracts Only (`AaveV4DeployBatchScript`)

Deploys all smart contracts and grants permanent roles. No assets are listed, no spokes are registered, no reserves are configured. Configuration is expected to happen later via governance payloads (Flow 3).

```
config/deploy.json
       |
  ConfigReader → _buildDeployInputs(grantRoles=true) → FullDeployInputs
       |
  AaveV4DeployOrchestration.deployAaveV4()
       |
       ├─ AccessBatch            → AccessManager
       ├─ ConfiguratorBatch      → HubConfigurator + SpokeConfigurator
       ├─ Setup selector→role mappings on AccessManager
       ├─ HubBatch × N           → Hub + IRStrategy + TreasurySpoke (per hub)
       │    └─ Setup hub selector→role mappings
       ├─ SpokeInstanceBatch × N → SpokeProxy + SpokeImpl + AaveOracle (per spoke)
       │    └─ Setup spoke selector→role mappings
       ├─ GatewayBatch           → NativeTokenGateway + SignatureGateway (if nativeWrapper set)
       └─ Grant permanent roles:
            ├─ hubAdmin → HUB_CONFIGURATOR_ROLE + HUB_FEE_MINTER_ROLE
            ├─ HubConfigurator contract → HUB_CONFIGURATOR_ROLE
            ├─ hubConfiguratorAdmin → all HubConfigurator granular roles (9-12)
            ├─ spokeAdmin → SPOKE_CONFIGURATOR_ROLE + SPOKE_POSITION_UPDATER_ROLE
            ├─ SpokeConfigurator contract → SPOKE_CONFIGURATOR_ROLE
            ├─ spokeConfiguratorAdmin → all SpokeConfigurator granular roles (13-15)
            └─ Replace DEFAULT_ADMIN_ROLE: deployer → accessManagerAdmin
```

**When to use:** You only need contracts deployed and roles assigned. Assets, spoke registrations, and reserves will be configured later via governance payloads.

```bash
# 1. Create config/deploy.json (fill in infrastructure, hubs, spokes sections)
cp config/template.json config/deploy.json

# 2. If deploying spokes, pre-deploy LiquidationLogic
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# 3. Deploy
forge script scripts/deploy/AaveV4DeployBatch.s.sol --broadcast --fork-url $RPC
```

### Flow 2: Contracts + Direct Configuration (`AaveV4FullDeployScript`)

Deploys all contracts, then configures them by calling HubConfigurator and SpokeConfigurator directly — no config engine or payload is involved. The deployer gets temporary admin roles for the configuration phase (V3 pattern), then those roles are revoked and permanent roles are granted.

```
config/deploy.json
       |
  ConfigReader → _buildDeployInputs(grantRoles=false) → FullDeployInputs
       |
  Step 1: AaveV4DeployOrchestration.deployAaveV4()
       |  (same contract deployment as Flow 1, but roles NOT granted yet)
       |
  Step 2: Grant structural + deployer temporary roles
       |  ├─ HubConfigurator → HUB_CONFIGURATOR_ROLE (5)
       |  ├─ SpokeConfigurator → SPOKE_CONFIGURATOR_ROLE (6)
       |  └─ deployer → temp roles (9, 13, 14, 15)
       |
  Step 3: Deployer calls configurators directly (no payload, no config engine)
       |  ├─ HubConfigurator.addAsset()           — list assets on hubs
       |  ├─ HubConfigurator.addSpoke()           — register spokes on hubs
       |  │    └─ optionally CREATE2-deploy TokenizationSpokeInstance
       |  ├─ SpokeConfigurator.updateMaxReserves() — set per-spoke max reserves
       |  ├─ SpokeConfigurator.addReserve()        — configure reserves on spokes
       |  └─ SpokeConfigurator.updateLiquidationConfig() — set liquidation params
       |
  Step 4: Revoke deployer temp roles (9, 13, 14, 15)
       |
  Step 5: Grant permanent roles + transfer DEFAULT_ADMIN_ROLE to final admin
```

**When to use:** Complete greenfield deployment — contracts, configuration, and role handoff in a single transaction.

```bash
# 1. Create config/deploy.json with ALL sections filled in:
#    infrastructure, hubs, spokes, tokens, assets, spokeRegistrations, reserves
cp config/template.json config/deploy.json

# 2. If deploying spokes, pre-deploy LiquidationLogic
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# 3. Full deploy
forge script scripts/deploy/AaveV4FullDeploy.s.sol:AaveV4FullDeployDefaultScript \
  --broadcast --fork-url $RPC
```

If no config sections are defined (empty assets/spokeRegistrations/reserves), falls back to Flow 1 behavior with `grantRoles=true`.

### Flow 3: Governance Payload (`AaveV4Payload`)

Post-deployment parameter changes via governance proposals. Uses the config engine + DELEGATECALL pattern — no deploy scripts involved. The governance executor (which holds AccessManager roles) calls `payload.execute()`, which delegates to stateless config engines that route calls through the configurators.

```
Governance / Timelock
       |
       | calls execute()
       v
  AaveV4Payload (per-proposal contract, extends AaveV4PayloadBase)
       |
       ├─ _executeHubPayload()                     hub operations first:
       │    ├─ newAssetListings()       → DELEGATECALL HubConfigEngine.listAssets()
       │    ├─ newSpokeListings()       → DELEGATECALL HubConfigEngine.addSpokes()
       │    ├─ assetLiquidityFeeUpdates()→ DELEGATECALL HubConfigEngine.updateAssetLiquidityFees()
       │    ├─ assetIRDataUpdates()     → DELEGATECALL HubConfigEngine.updateAssetIRData()
       │    ├─ assetIRStrategyUpdates() → DELEGATECALL HubConfigEngine.updateAssetIRStrategies()
       │    ├─ assetFeeReceiverUpdates()→ DELEGATECALL HubConfigEngine.updateAssetFeeReceivers()
       │    ├─ reinvestmentControllerUpdates()→ DELEGATECALL HubConfigEngine.updateReinvestmentControllers()
       │    ├─ spokeCapUpdates()        → DELEGATECALL HubConfigEngine.updateSpokeCaps()
       │    ├─ spokeActiveUpdates()     → DELEGATECALL HubConfigEngine.updateSpokeActive()
       │    ├─ spokeHaltedUpdates()     → DELEGATECALL HubConfigEngine.updateSpokeHalted()
       │    └─ spokeRiskPremiumUpdates()→ DELEGATECALL HubConfigEngine.updateSpokeRiskPremiumThresholds()
       │
       └─ _executeSpokePayload()                   then spoke operations:
            ├─ newReserveListings()     → DELEGATECALL SpokeConfigEngine.listReserves()
            ├─ liquidationConfig()      → DELEGATECALL SpokeConfigEngine.updateLiquidationConfig()
            ├─ reserveConfigUpdates()   → DELEGATECALL SpokeConfigEngine.updateReserves()
            └─ dynamicConfigUpdates()   → DELEGATECALL SpokeConfigEngine.updateDynamicConfigs()
       |
       v
  HubConfigurator / SpokeConfigurator (AccessManaged) → Hub / Spoke
```

**When to use:** Any configuration change after initial deployment — listing new assets, updating fees, adding reserves, changing liquidation parameters, toggling spoke active/halted, etc.

**How it works:** DELEGATECALL preserves `msg.sender` (the governance executor), which holds the AccessManager roles needed to call HubConfigurator/SpokeConfigurator. The config engines are stateless — all state lives in the payload contract's immutables. Override only the hooks you need; unused hooks return empty arrays and are skipped.

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

### Flow Comparison

| Concern                | Flow 1: Contracts Only       | Flow 2: Contracts + Config          | Flow 3: Governance Payload        |
| ---------------------- | ---------------------------- | ----------------------------------- | --------------------------------- |
| When                   | Initial deployment           | Initial greenfield deployment       | Post-deployment changes           |
| Who                    | Deployer EOA                 | Deployer EOA                        | Governance / Timelock             |
| Contracts deployed     | Yes                          | Yes                                 | No (already deployed)             |
| Assets/reserves config | No                           | Yes (direct configurator calls)     | Yes (via config engine + payload) |
| Config engine used     | No                           | No                                  | Yes (DELEGATECALL)                |
| Roles                  | Granted immediately          | Deployer temp → revoked → permanent | Governance holds permanent roles  |
| Config format          | JSON (ConfigReader)          | JSON (ConfigReader)                 | Solidity (payload hooks)          |
| JSON sections needed   | infrastructure, hubs, spokes | All sections                        | N/A                               |

## Deployment Order

A full Aave V4 deployment (Flow 2) proceeds in this order:

```
1. LiquidationLogic library (external library, must be pre-deployed)
2. AccessManager + AccessManagerEnumerable          (AaveV4AccessBatch)
3. HubConfigurator + SpokeConfigurator              (AaveV4ConfiguratorBatch)
4. Configure selector→role mappings on AccessManager
5. Hub(s) + InterestRateStrategy + TreasurySpoke    (AaveV4HubBatch, per hub)
6. SpokeInstance(s) + AaveOracle                    (AaveV4SpokeInstanceBatch, per spoke)
7. Deploy periphery (gateways)                      (AaveV4GatewayBatch)
8. Grant structural + deployer temp roles
9. List assets on hub(s)                            (deployer → HubConfigurator)
10. Register spokes on hub(s)                       (deployer → HubConfigurator)
11. Configure reserves on spoke(s)                  (deployer → SpokeConfigurator)
12. Set liquidation config on spoke(s)              (deployer → SpokeConfigurator)
13. Revoke deployer temp roles
14. Grant permanent admin roles
15. Transfer DEFAULT_ADMIN_ROLE to governance
```

Flow 1 covers steps 1-7 then jumps to 14-15. Flow 3 handles steps 9-12 (and equivalent updates) via governance after deployment.

### LiquidationLogic Pre-deployment

`LiquidationLogic` is an external Solidity library used by `Spoke.sol` (via `SpokeInstance`). Because it has `public`/`external` functions, the compiler emits it as a separate contract that `SpokeInstance` calls via `DELEGATECALL` at runtime. When Solidity compiles `SpokeInstance`, it leaves placeholder references (`__$<hash>$__`) in the bytecode where the library address should go. You cannot deploy `SpokeInstance` until those placeholders are replaced with a real on-chain address.

This requires a **two-step deploy** because Foundry needs to re-compile with the library address baked into the bytecode, which can only happen on the next invocation:

**Step 1 — `LibraryPreCompile.s.sol`** (separate transaction):

1. `SpokeDeployUtils.deployLiquidationLogic()` gets the library bytecode via `vm.getCode()` and deploys it via CREATE2 with `salt=0`
2. Writes `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x<address>` to `.env` via FFI
3. On re-run: if the library is already deployed (has code), skips. If `FOUNDRY_LIBRARIES` exists but the library isn't deployed (wrong chain/fork), deletes the stale entry and asks you to run again

**Step 2 — Main deploy script** (next invocation):

1. Foundry reads `.env` at startup, sees `FOUNDRY_LIBRARIES`, and at compile time replaces all `__$<hash>$__` placeholders in `SpokeInstance`'s bytecode with the library address
2. `_requireLiquidationLogicLinked()` in `AaveV4FullDeployScript` verifies both: (a) `FOUNDRY_LIBRARIES` exists in `.env`, and (b) the address has code on-chain
3. `AaveV4SpokeInstanceBatch` deploys `SpokeInstance` with fully linked bytecode

```bash
# Step 1: Deploy LiquidationLogic and set FOUNDRY_LIBRARIES in .env
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# Step 2: Run the main deploy script (Foundry auto-links via FOUNDRY_LIBRARIES)
forge script scripts/deploy/AaveV4FullDeploy.s.sol --broadcast --fork-url $RPC --ffi

# Or via Makefile:
make deploy-precompile CHAIN=<chain>
make deploy-full CHAIN=<chain>
```

**In tests:** `dynamic_test_linking = true` in `foundry.toml` tells Foundry to auto-deploy external libraries during test execution, so no `LibraryPreCompile` step is needed.

## Config Engines

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
