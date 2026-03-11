# Aave V4 Deployment Infrastructure

Infrastructure for deploying and configuring the Aave V4 hub-and-spoke protocol.

## Quickstart

Deploys all contracts and grants permanent roles. No assets are listed, no spokes are registered, no reserves are configured — that happens later via governance payloads.

### 1. Configure `.env`

Copy `.env.example` and set:

| Variable  | Description                                              |
| --------- | -------------------------------------------------------- |
| `CHAIN`   | Target chain name (must match a Foundry profile and RPC) |
| `ACCOUNT` | Foundry keystore account name for the deployer           |
| `DRY`     | Leave blank to broadcast; set to a value to simulate     |

The deploy script constructs a `FullDeployInputs` struct (see `src/deployments/utils/InputUtils.sol`) with admin addresses, hub/spoke labels, CREATE2 salt, and gateway flags. Override `_getDeployInputs()` in your chain-specific script (extends `AaveV4DeployBatchBase.s.sol`) to provide these values. Any zero-address admin fields default to the deployer.

### 2. Pre-deploy LiquidationLogic (required for spokes)

```bash
make deploy-precompile
```

This deploys `LiquidationLogic` via CREATE2 and writes `FOUNDRY_LIBRARIES` to `.env` so Foundry can link `SpokeInstance` bytecode on the next compilation. See [LiquidationLogic Pre-deployment](#liquidationlogic-pre-deployment) for details.

### 3. Deploy

```bash
make deploy-contracts
```

This runs `AaveV4DeployOrchestration.deployAaveV4()`, which deploys batches in order: AccessManager → Configurators → TreasurySpoke → Hubs → Spokes → Gateways → role grants → DEFAULT_ADMIN transfer.

### LiquidationLogic Pre-deployment

`LiquidationLogic` is an external Solidity library used by `Spoke.sol` (via `SpokeInstance`). Because it has `public`/`external` functions, the compiler emits it as a separate contract that `SpokeInstance` calls via `DELEGATECALL` at runtime. When Solidity compiles `SpokeInstance`, it leaves placeholder references (`__$<hash>$__`) in the bytecode where the library address should go. You cannot deploy `SpokeInstance` until those placeholders are replaced with a real on-chain address.

This requires a **two-step deploy** because Foundry needs to re-compile with the library address baked into the bytecode, which can only happen on the next invocation:

**Step 1 — `LibraryPreCompile.s.sol`** (separate transaction):

1. `SpokeDeployUtils.deployLiquidationLogic()` gets the library bytecode via `vm.getCode()` and deploys it via CREATE2 with `salt=0`
2. Writes `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x<address>` to `.env` via FFI
3. On re-run: if the library is already deployed (has code), skips. If `FOUNDRY_LIBRARIES` exists but the library isn't deployed (wrong chain/fork), deletes the stale entry and asks you to run again

**Step 2 — Main deploy script** (next invocation):

1. Foundry reads `.env` at startup, sees `FOUNDRY_LIBRARIES`, and at compile time replaces all `__$<hash>$__` placeholders in `SpokeInstance`'s bytecode with the library address
2. `AaveV4SpokeInstanceBatch` deploys `SpokeInstance` with fully linked bytecode

**In tests:** `dynamic_test_linking = true` in `foundry.toml` tells Foundry to auto-deploy external libraries during test execution, so no `LibraryPreCompile` step is needed.

## Architecture

```
scripts/deploy/
  AaveV4DeployBatchBase.s.sol     Base: deploy-only run()

src/deployments/
  batches/                    Batch constructors -- deploy related contracts together
    AaveV4AuthorityBatch        AccessManagerEnumerable
    AaveV4ConfiguratorBatch     HubConfigurator, SpokeConfigurator
    AaveV4TreasurySpokeBatch    TreasurySpoke (single instance, proxy + impl)
    AaveV4HubBatch              Hub, InterestRateStrategy
    AaveV4SpokeInstanceBatch    SpokeInstance (proxy), AaveOracle
    AaveV4GatewayBatch          NativeTokenGateway, SignatureGateway

  orchestration/              High-level orchestrators
    AaveV4DeployOrchestration   Main entry: deployAaveV4() -- calls batches in order
    AaveV4DeployBase            Static deploy helpers for each batch

  procedures/                 Granular operations
    config/                   Hub/Spoke configuration procedures
    deploy/                   Individual contract deploy procedures
    roles/                    Role setup procedures per component

  libraries/
    BatchReports              Report structs for each batch
    OrchestrationReports      Full deployment report aggregation
    ConfigData                Parameter structs for config operations

  utils/
    InputUtils                FullDeployInputs struct
    Roles                     Role ID constants (0, 1-3, 100-113, 200-201, 301-309)
    Create2Utils              Deterministic deployment helpers
    Logger / MetadataLogger   Deployment logging and JSON output
```

### Roles (Roles.sol)

Roles are namespaced by contract domain: Hub (1-3), HubConfigurator (100-113), Spoke (200-201), SpokeConfigurator (301-309).

#### `AccessManager` Role

| ID  | Name               | Granted To         | Notes                                                             |
| --- | ------------------ | ------------------ | ----------------------------------------------------------------- |
| 0   | DEFAULT_ADMIN_ROLE | accessManagerAdmin | OpenZeppelin built-in. Transferred from deployer at end of deploy |

#### `Hub` Roles

| ID  | Name                        | Granted To                         | Functions                                                                     |
| --- | --------------------------- | ---------------------------------- | ----------------------------------------------------------------------------- |
| 1   | HUB_CONFIGURATOR_ROLE       | hubAdmin, HubConfigurator contract | addAsset, updateAssetConfig, addSpoke, updateSpokeConfig, setInterestRateData |
| 2   | HUB_FEE_MINTER_ROLE         | hubAdmin                           | mintFeeShares                                                                 |
| 3   | HUB_DEFICIT_ELIMINATOR_ROLE | hubAdmin                           | eliminateDeficit                                                              |

#### `HubConfigurator` Roles

| ID  | Name                                                 | Functions                                           |
| --- | ---------------------------------------------------- | --------------------------------------------------- |
| 100 | HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE          | updateLiquidityFee                                  |
| 101 | HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE               | updateFeeReceiver, updateFeeConfig                  |
| 102 | HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE           | updateReinvestmentController                        |
| 103 | HUB_CONFIGURATOR_HALTER_ROLE                         | haltAsset, haltSpoke, updateSpokeHalted             |
| 104 | HUB_CONFIGURATOR_DEACTIVATOR_ROLE                    | deactivateAsset, deactivateSpoke, updateSpokeActive |
| 105 | HUB_CONFIGURATOR_CAPS_RESETTER_ROLE                  | resetAssetCaps, resetSpokeCaps                      |
| 106 | HUB_CONFIGURATOR_CAPS_UPDATER_ROLE                   | updateSpokeCaps                                     |
| 107 | HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE               | updateSpokeDrawCap                                  |
| 108 | HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE                | updateSpokeAddCap                                   |
| 109 | HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE               | updateSpokeRiskPremiumThreshold                     |
| 110 | HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE | updateInterestRateStrategy                          |
| 111 | HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE     | updateInterestRateData                              |
| 112 | HUB_CONFIGURATOR_ASSET_LISTER_ROLE                   | addAsset, addAssetWithDecimals                      |
| 113 | HUB_CONFIGURATOR_SPOKE_ADDER_ROLE                    | addSpoke, addSpokeToAssets                          |

#### `Spoke` Roles (on Spoke contract)

| ID  | Name                             | Granted To                             | Functions                                                                                                                                                      |
| --- | -------------------------------- | -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 200 | SPOKE_USER_POSITION_UPDATER_ROLE | spokeAdmin                             | updateUserDynamicConfig, updateUserRiskPremium                                                                                                                 |
| 201 | SPOKE_CONFIGURATOR_ROLE          | spokeAdmin, SpokeConfigurator contract | updateLiquidationConfig, addReserve, updateReserveConfig, updateDynamicReserveConfig, addDynamicReserveConfig, updatePositionManager, updateReservePriceSource |

#### `SpokeConfigurator` Roles (on SpokeConfigurator contract)

| ID  | Name                                                | Functions                                                                                                                 |
| --- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| 301 | SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE                 | updateReservePriceSource                                                                                                  |
| 302 | SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE               | updateCollateralRisk, updateReceiveSharesEnabled, updateBorrowable                                                        |
| 303 | SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE       | addCollateralFactor, updateCollateralFactor, addDynamicReserveConfig, updateDynamicReserveConfig                          |
| 304 | SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE      | updatePositionManager                                                                                                     |
| 305 | SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE         | updateLiquidationTargetHealthFactor, updateHealthFactorForMaxBonus, updateLiquidationBonusFactor, updateLiquidationConfig |
| 306 | SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE | addMaxLiquidationBonus, updateMaxLiquidationBonus, addLiquidationFee, updateLiquidationFee                                |
| 307 | SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE               | addReserve                                                                                                                |
| 308 | SPOKE_CONFIGURATOR_FREEZER_ROLE                     | updateFrozen, freezeAllReserves, freezeReserve                                                                            |
| 309 | SPOKE_CONFIGURATOR_PAUSER_ROLE                      | updatePaused, pauseAllReserves, pauseReserve                                                                              |

## Data Flow

```
FullDeployInputs                 (transport struct: addresses, labels, per-spoke config, salt)
       |
       v
  AaveV4DeployOrchestration.deployAaveV4()
       |
       +-- deployAuthorityBatch()         --> AccessManager
       +-- deployConfiguratorBatch()   --> HubConfigurator, SpokeConfigurator
       +-- setupConfiguratorRoles()    --> selector->role mappings
       +-- deployTreasurySpokeBatch()   --> TreasurySpoke
       +-- deployHubs(hubLabels)       --> Hub[], IRStrategy[]
       +-- deploySpokes(spokeLabels, spokeMaxReservesLimits)
       |                               --> SpokeProxy[], AaveOracle[]
       +-- deployGateways()            --> NativeTokenGateway, SignatureGateway
       +-- grantRoles() (if enabled)   --> admin role grants + DEFAULT_ADMIN transfer
       |
       v
  FullDeploymentReport            (all deployed addresses)
```
