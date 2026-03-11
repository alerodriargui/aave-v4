# Aave V4 Deployment Infrastructure

Infrastructure for deploying and configuring the Aave V4 hub-and-spoke protocol.

## Deployment Flow

Deploys all smart contracts and grants permanent roles. No assets are listed, no spokes are registered, no reserves are configured. Configuration is expected to happen later via governance payloads.

```
FullDeployInputs (constructed in script)
       |
  AaveV4DeployOrchestration.deployAaveV4()
       |
       ├─ AuthorityBatch            → AccessManagerEnumerable
       ├─ ConfiguratorBatch         → HubConfigurator + SpokeConfigurator
       ├─ Setup selector→role mappings on AccessManager
       ├─ TreasurySpokeBatch        → TreasurySpoke (single instance, deployed once)
       ├─ HubBatch × N              → Hub + IRStrategy (per hub)
       │    └─ Setup hub selector→role mappings
       ├─ SpokeInstanceBatch × N    → SpokeProxy + SpokeImpl + AaveOracle (per spoke)
       │    └─ Setup spoke selector→role mappings
       ├─ GatewayBatch              → NativeTokenGateway + SignatureGateway (if nativeWrapper set)
       └─ Grant permanent roles:
            ├─ Hub roles (on Hub contract):
            │    ├─ hubAdmin → HUB_CONFIGURATOR_ROLE (1) + HUB_FEE_MINTER_ROLE (2)
            │    └─ HubConfigurator contract → HUB_CONFIGURATOR_ROLE (1)
            ├─ HubConfigurator roles (on HubConfigurator contract):
            │    └─ hubConfiguratorAdmin → all granular roles (100-113)
            ├─ Spoke roles (on Spoke contract):
            │    ├─ spokeAdmin → SPOKE_CONFIGURATOR_ROLE (201) + SPOKE_USER_POSITION_UPDATER_ROLE (200)
            │    └─ SpokeConfigurator contract → SPOKE_CONFIGURATOR_ROLE (201)
            ├─ SpokeConfigurator roles (on SpokeConfigurator contract):
            │    └─ spokeConfiguratorAdmin → all granular roles (301-309)
            └─ Replace DEFAULT_ADMIN_ROLE: deployer → accessManagerAdmin
```

```bash
# 1. If deploying spokes, pre-deploy LiquidationLogic
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# 2. Deploy
forge script scripts/deploy/AaveV4DeployBatch.s.sol --broadcast --fork-url $RPC
```

### Deployment Order

```
1. LiquidationLogic library (external library, must be pre-deployed)
2. AccessManagerEnumerable                           (AaveV4AuthorityBatch)
3. HubConfigurator + SpokeConfigurator              (AaveV4ConfiguratorBatch)
4. Configure selector→role mappings on AccessManager
5. TreasurySpoke (single instance)                   (AaveV4TreasurySpokeBatch)
6. Hub(s) + InterestRateStrategy                     (AaveV4HubBatch, per hub)
7. SpokeInstance(s) + AaveOracle                     (AaveV4SpokeInstanceBatch, per spoke)
8. Deploy periphery (gateways)                       (AaveV4GatewayBatch)
9. Grant permanent admin roles
10. Transfer DEFAULT_ADMIN_ROLE to governance
```

### LiquidationLogic Pre-deployment

`LiquidationLogic` is an external Solidity library used by `Spoke.sol` (via `SpokeInstance`). Because it has `public`/`external` functions, the compiler emits it as a separate contract that `SpokeInstance` calls via `DELEGATECALL` at runtime. When Solidity compiles `SpokeInstance`, it leaves placeholder references (`__$<hash>$__`) in the bytecode where the library address should go. You cannot deploy `SpokeInstance` until those placeholders are replaced with a real on-chain address.

This requires a **two-step deploy** because Foundry needs to re-compile with the library address baked into the bytecode, which can only happen on the next invocation:

**Step 1 — `LibraryPreCompile.s.sol`** (separate transaction):

1. `SpokeDeployUtils.deployLiquidationLogic()` gets the library bytecode via `vm.getCode()` and deploys it via CREATE2 with `salt=0`
2. Writes `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0x<address>` to `.env` via FFI
3. On re-run: if the library is already deployed (has code), skips. If `FOUNDRY_LIBRARIES` exists but the library isn't deployed (wrong chain/fork), deletes the stale entry and asks you to run again

**Step 2 — Main deploy script** (next invocation):

1. Foundry reads `.env` at startup, sees `FOUNDRY_LIBRARIES`, and at compile time replaces all `__$<hash>$__` placeholders in `SpokeInstance`'s bytecode with the library address
2. The deploy script verifies both: (a) `FOUNDRY_LIBRARIES` exists in `.env`, and (b) the address has code on-chain
3. `AaveV4SpokeInstanceBatch` deploys `SpokeInstance` with fully linked bytecode

```bash
# Step 1: Deploy LiquidationLogic and set FOUNDRY_LIBRARIES in .env
forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi

# Step 2: Run the main deploy script (Foundry auto-links via FOUNDRY_LIBRARIES)
forge script scripts/deploy/AaveV4DeployBatch.s.sol --broadcast --fork-url $RPC
```

**In tests:** `dynamic_test_linking = true` in `foundry.toml` tells Foundry to auto-deploy external libraries during test execution, so no `LibraryPreCompile` step is needed.

## Architecture

```
scripts/deploy/
  AaveV4DeployBatchBase.s.sol     Base: deploy-only run()

src/deployments/
  batches/                    Batch constructors -- deploy related contracts together
    AaveV4AuthorityBatch           AccessManagerEnumerable
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

#### Hub Roles (on Hub contract)

| ID  | Name                        | Granted To               | Functions                                                                     |
| --- | --------------------------- | ------------------------ | ----------------------------------------------------------------------------- |
| 0   | DEFAULT_ADMIN_ROLE          | AccessManager admin      | AccessManager admin operations                                                |
| 1   | HUB_CONFIGURATOR_ROLE       | HubConfigurator contract | addAsset, updateAssetConfig, addSpoke, updateSpokeConfig, setInterestRateData |
| 2   | HUB_FEE_MINTER_ROLE         | feeMinter contract       | mintFeeShares                                                                 |
| 3   | HUB_DEFICIT_ELIMINATOR_ROLE | umbrella spoke           | eliminateDeficit                                                              |

#### HubConfigurator Roles (on HubConfigurator contract)

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

#### Spoke Roles (on Spoke contract)

| ID  | Name                             | Granted To                 | Functions                                                                                                                                                      |
| --- | -------------------------------- | -------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 200 | SPOKE_USER_POSITION_UPDATER_ROLE | executor lvl1              | updateUserDynamicConfig, updateUserRiskPremium                                                                                                                 |
| 201 | SPOKE_CONFIGURATOR_ROLE          | SpokeConfigurator contract | updateLiquidationConfig, addReserve, updateReserveConfig, updateDynamicReserveConfig, addDynamicReserveConfig, updatePositionManager, updateReservePriceSource |

#### SpokeConfigurator Roles (on SpokeConfigurator contract)

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
