# Aave V4 Deployment Scripts

Keep this file up to date as the deployment script evolves.

## Overview

JSON-driven deployment system for Aave V4. All configuration lives in `config/<network>.json`, read by `scripts/Script.s.sol` at runtime via Foundry's `stdJson`. The config path defaults to `config/mainnet.json` and can be overridden with `CONFIG_PATH` env var.

## File Map

| File | Purpose |
|------|---------|
| `config/mainnet.json` | Deployment config (tokens, hubs, spokes, assets, spoke registrations, reserves, periphery) |
| `scripts/Script.s.sol` | Main deploy script (`Deploy` contract) |
| `scripts/SpokeDeployUtils.sol` | Spoke deployment library + FfiUtils for `FOUNDRY_LIBRARIES` .env management |
| `scripts/LibraryPreCompile.s.sol` | Preprocessing script: deploys LiquidationLogic, writes `FOUNDRY_LIBRARIES` to `.env` |
| `scripts/ConfigReader.sol` | Library for reading `config/<network>.json` with 3-level default resolution via `stdJson` |
| `scripts/ScriptUtils.sol` | Shared utility library: `strEq()`, `assetId()`, `slice()`, `commit()` |
| `scripts/DeployLogger.sol` | Dual-output logging library (console2 + JSONL file) |
| `scripts/validate-config.ts` | TypeScript + Zod config validator — schema validation, referential integrity, constraint violations, warnings |
| `scripts/deploy/Deploy.s.sol` | Modular deploy entry point (`DeployV4` contract): `run()` for full deployment, `load()` for restoring state |
| `scripts/deploy/DeployTypes.sol` | `DeployReport` struct, sub-report structs (`HubReport`, `SpokeReport`, `TokenReport`, `TokenizationReport`), `DeployReportLib` finder helpers |
| `scripts/deploy/DeployInfra.sol` | Library: AccessManager, tokens (+ mock feeds), spokes (oracle + SpokeInstance), hubs (Hub + TreasurySpoke + IRStrategy) |
| `scripts/deploy/DeployMarket.sol` | Library: asset listing, spoke registration, tokenization spoke deployment |
| `scripts/deploy/DeployPeriphery.sol` | Library: AccessManager roles, reserves + liquidation configs, gateways + PM registration, configurator deployment |
| `scripts/deploy/ReportIO.sol` | Library: serialize `DeployReport` → JSON (`writeReport`), deserialize JSON → `DeployReport` (`readReport`) |
| `tests/DeployUtils.sol` | Hub deployment via `vm.getCode` + CREATE2, `proxify()` for TransparentUpgradeableProxy |
| `tests/Create2Utils.sol` | CREATE2 factory wrapper (safe-global at `0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7`) |
| `tests/DeployReader.sol` | Library for reading `output/deploy.json` addresses via `stdJson` (mirrors ConfigReader pattern) |
| `tests/DeployValidation.t.sol` | Post-deployment validation: 13 test functions verify on-chain state matches config |
| `output/deploy.json` | Written by `logAddy()` — all deployed addresses + git commit hash |

## Data Model

```
Hub ──1:N──► Asset        (hub.addAsset → assetId)
Hub ──1:N──► SpokeData    (hub.addSpoke(assetId, spoke, SpokeConfig) → per-asset registration)
Spoke ──1:N──► Reserve    (spoke.addReserve(hub, assetId, ...) → reserveId)
```

A **Reserve** on a Spoke points to exactly one (hub, assetId) pair. The spoke must also be **registered** on that hub for that assetId via `hub.addSpoke()`.

**Key invariant:** A spoke can be registered on a hub it doesn't "belong to" (cross-hub borrowing). Example: ETHENA_SPOKE registered on CORE_HUB for USDC.

## Deployment Order (`run()`)

### Modular script (`scripts/deploy/Deploy.s.sol:DeployV4`)

```
DeployInfra.setUpTokens          — populate tokens + mock feeds
DeployInfra.deployInfrastructure — AccessManager, spokes (oracle + SpokeInstance), hubs (Hub + TreasurySpoke + IRStrategy)
DeployPeriphery.setUpRoles       — AccessManager selector→role mappings for all hubs/spokes
DeployMarket.configureMarkets    — asset listing, spoke registration, tokenization spokes
DeployPeriphery.setUpReserves    — reserves + liquidation configs
DeployPeriphery.deployGateways   — SignatureGateway + NativeTokenGateway + PM registration
DeployPeriphery.deployConfigurators — HubConfigurator + SpokeConfigurator + Level 1+2 role setup
ReportIO.writeReport             — serialize to output/deploy.json
```

```bash
# Full deployment on local anvil
forge script scripts/deploy/Deploy.s.sol:DeployV4 \
  --broadcast --rpc-url anvil -s "run()" \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked --slow --legacy --offline
```

### Legacy script (`scripts/Script.s.sol:Deploy`)

```
_loadConfig → setUpTokens → setUpHubs → setUpReserves → periphery → _deployConfigurators → logAddy
                               │
                               ├─ deploySpokes()      — oracle + SpokeInstance (CREATE2 + proxy)
                               ├─ deploy hubs          — Hub (CREATE2 with hubKey-derived salt)
                               ├─ setUpRoles(hubKey)   — per-hub AccessManager role mappings
                               ├─ list assets           — hub.addAsset + updateAssetConfig
                               └─ register spokes       — hub.addSpoke per (asset, spoke) pair
```

## Script Entry Points

### `scripts/deploy/Deploy.s.sol:DeployV4` (modular)

| Function | Selector | Purpose |
|----------|----------|---------|
| `run()` | default | Full fresh deployment using modular libraries |
| `load()` | public | Restore `DeployReport` from `output/deploy.json` |

### `scripts/Script.s.sol:Deploy` (legacy)

| Function | Selector | Purpose |
|----------|----------|---------|
| `run()` | default | Full fresh deployment (monolithic) |
| `debug()` | `-s "debug()"` | Load existing deployment from `output/deploy.json`, add manual operations in function body |
| `seed()` | `-s "seed()"` | Load deployment, run supply/borrow/repay operations for testing |
| `deployConfigurator()` | `-s "deployConfigurator()"` | Standalone: load existing deployment, deploy HubConfigurator + SpokeConfigurator with full role setup |
| `load()` | internal | Restore all state from `output/deploy.json` into memory (used by debug/seed/deployConfigurator) |

Always use `--rpc-url anvil --offline` for local deployments. The `anvil` network is configured in `foundry.toml`.

## Config Schema (`config/<network>.json`)

```jsonc
{
  "defaults": {
    "spoke": {
      "oracleDecimals": 8,          // uint8, default for AaveOracle decimals
      "maxUserReservesLimit": 128,   // uint16, default max reserves per user on spoke
      "liquidationConfig": {         // defaults for individual liquidationConfig fields
        "targetHealthFactor": "1050000000000000000",    // uint128, WAD (1.05)
        "healthFactorForMaxBonus": "700000000000000000", // uint64, WAD (0.7)
        "liquidationBonusFactor": 2000                   // uint16, BPS (20%)
      }
    },
    "spokeRegistration": {
      "riskPremiumThreshold": 100000,  // uint24, default BPS
      "active": true,
      "halted": false
    },
    "reserve": {
      "receiveSharesEnabled": true,
      "frozen": false,
      "paused": false,
      "liquidationFee": 1000,          // uint16, BPS (10%)
      "maxLiquidationBonus": 10500     // uint32, BPS (105%)
    },
    "asset": {
      "liquidityFee": 1000           // uint16, BPS (10%)
    },
    "tokenize": {
      "enabled": true,               // bool, deploy TokenizationSpoke for each asset (default true)
      "addCap": 1099511627775        // optional, uint40, supply cap (default type(uint40).max)
    }
  },

  "tokens": {
    "KEY": {
      "address": "0x...",           // on-chain token address
      "priceFeed": "0x..."          // Chainlink feed; 0x0 = mock feed deployed at runtime
    }
  },

  "hubs": [
    { "key": "HUB_NAME" }           // each hub gets its own TreasurySpoke + AssetInterestRateStrategy
  ],

  "spokes": [
    {
      "key": "SPOKE_NAME",
      "registerOnPositionManagers": true,   // optional, default true
      "oracleDecimals": 8,                  // optional, overrides defaults.spoke.oracleDecimals
      "maxUserReservesLimit": 128,          // optional, overrides defaults.spoke.maxUserReservesLimit
      "liquidationConfig": {                // optional; if present, each field is also optional (defaults from defaults.spoke.liquidationConfig)
        "targetHealthFactor": "1050000000000000000",    // optional, uint128, WAD (1e18 = 100%)
        "healthFactorForMaxBonus": "700000000000000000", // optional, uint64, WAD
        "liquidationBonusFactor": 2000                   // optional, uint16, BPS
      }
    }
  ],

  "assets": [
    {
      "tokenKey": "KEY",            // must exist in tokens
      "hubKey": "HUB_NAME",         // must exist in hubs
      "liquidityFee": 1000,         // optional, uint16, BPS (default from defaults.asset.liquidityFee)
      "irData": {
        "optimalUsageRatio": 9000,        // uint16, BPS
        "baseVariableBorrowRate": 0,      // uint32, BPS
        "variableRateSlope1": 270,        // uint32, BPS
        "variableRateSlope2": 8000        // uint32, BPS
      },
      "tokenize": {                       // optional, overrides defaults.tokenize
        "enabled": false,                 // optional, override enabled flag
        "addCap": 500                     // optional, override addCap
      }
    }
  ],

  "spokeRegistrations": [
    {
      "assetKey": "KEY",            // must exist in tokens
      "hubKey": "HUB_NAME",         // must exist in hubs
      "spokeKey": "SPOKE_NAME",     // must exist in spokes
      "addCap": 225,                // uint40, whole tokens (0 = can't supply)
      "drawCap": 200,               // uint40, whole tokens (0 = can't borrow)
      "riskPremiumThreshold": 100000,  // optional, overrides default
      "active": true,               // optional, overrides default
      "halted": false               // optional, overrides default
    }
  ],

  "reserves": [
    {
      "spokeKey": "SPOKE_NAME",     // must exist in spokes
      "hubKey": "HUB_NAME",         // must exist in hubs
      "assetKey": "KEY",            // must exist in tokens
      "borrowable": true,
      "collateralFactor": 8500,     // uint16, BPS (must be < 10000)
      "maxLiquidationBonus": 10500, // optional, uint32, BPS (default from defaults.reserve.maxLiquidationBonus, must be >= 10000)
      "liquidationFee": 1000,       // optional, uint16, BPS (default from defaults.reserve.liquidationFee, max 10000)
      "collateralRisk": 0,          // uint24, BPS (max 100000)
      "receiveSharesEnabled": true, // optional, overrides default
      "frozen": false,              // optional, overrides default
      "paused": false               // optional, overrides default
    }
  ],

  "periphery": {
    "nativeTokenKey": "WETH",                // must exist in tokens
    "deploySignatureGateway": true,
    "deployNativeTokenGateway": true
  }
}
```

### Referential Integrity Rules

- Every `tokenKey`/`assetKey` must exist in `tokens`
- Every `hubKey` must exist in `hubs`
- Every `spokeKey` must exist in `spokes`
- Every spokeRegistration must have a matching asset (same tokenKey+hubKey)
- Every reserve must have a matching asset AND a matching spokeRegistration
- `collateralFactor < 10000` and `maxLiquidationBonus >= 10000`
- `percentMulUp(maxLiquidationBonus, collateralFactor) < 10000`
- When `collateralFactor=0`, `maxLiquidationBonus=10000` is valid (non-collateral reserve)

Run `bun scripts/validate-config.ts [path]` to check these before deploying. Tests: `bun test scripts/validate-config.test.ts`.

## Struct Reference

```
IHub.SpokeConfig:            {addCap, drawCap, riskPremiumThreshold, active, halted}
ISpoke.ReserveConfig:        {collateralRisk, paused, frozen, borrowable, receiveSharesEnabled}
ISpoke.DynamicReserveConfig: {collateralFactor, maxLiquidationBonus, liquidationFee}
ISpoke.LiquidationConfig:   {targetHealthFactor (uint128 WAD), healthFactorForMaxBonus (uint64 WAD), liquidationBonusFactor (uint16 BPS)}
InterestRateData:            {optimalUsageRatio (uint16), baseVariableBorrowRate (uint32), variableRateSlope1 (uint32), variableRateSlope2 (uint32)}
```

## Access Control (AccessManager Roles)

```
Role ID  Name                        Granted to
0        DEFAULT_ADMIN_ROLE          ADMIN (deployer)
1        HUB_ADMIN_ROLE              ADMIN, HubConfigurator
2        SPOKE_ADMIN_ROLE            ADMIN, SpokeConfigurator
3        USER_POSITION_UPDATER_ROLE  (not granted in deploy script)
4        HUB_CONFIGURATOR_ROLE       (grant to governance/multisig post-deploy)
5        SPOKE_CONFIGURATOR_ROLE     (grant to governance/multisig post-deploy)
6        DEFICIT_ELIMINATOR_ROLE     (not granted in deploy script)
```

### `setUpRoles(hubKey)` — per-hub role mappings

Sets `setTargetFunctionRole` on each hub and spoke:

**Spoke → SPOKE_ADMIN_ROLE** (7 selectors): updateLiquidationConfig, addReserve, updateReserveConfig, updateDynamicReserveConfig, addDynamicReserveConfig, updatePositionManager, updateReservePriceSource

**Spoke → USER_POSITION_UPDATER_ROLE** (2 selectors): updateUserDynamicConfig, updateUserRiskPremium

**Hub → HUB_ADMIN_ROLE** (6 selectors): addAsset, updateAssetConfig, addSpoke, updateSpokeConfig, setInterestRateData, mintFeeShares

**Hub → DEFICIT_ELIMINATOR_ROLE** (1 selector): eliminateDeficit

### `_deployConfigurators()` — configurator role setup

Deploys HubConfigurator and SpokeConfigurator with `address(ACCESS_MANAGER)` as authority.

**Level 1**: Grants admin roles so configurators can call Hub/Spoke functions directly.

**Level 2**: Maps all configurator function selectors to configurator roles via `setTargetFunctionRole`:
- HubConfigurator (22 functions) → HUB_CONFIGURATOR_ROLE
- SpokeConfigurator (25 functions) → SPOKE_CONFIGURATOR_ROLE

Post-deployment, grant HUB_CONFIGURATOR_ROLE / SPOKE_CONFIGURATOR_ROLE to governance addresses.

## LiquidationLogic Library Linking

`SpokeInstance` uses `LiquidationLogic` as an external library. The artifact contains unlinked placeholders. Two-step process:

1. **LibraryPreCompile.s.sol**: Deploys `LiquidationLogic` via CREATE2, writes `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0xADDR` to `.env`
2. **Script.s.sol**: Forge reads `.env`, links library at compile time. `vm.getCode('SpokeInstance')` returns linked bytecode.

Must run LibraryPreCompile BEFORE main deploy. Script checks and reverts with clear message if not done.

Hub has NO library dependencies — `vm.getCode('Hub')` works without preprocessing.

## Compilation Restrictions

```toml
# foundry.toml
compilation_restrictions = [
  { paths = "src/hub/Hub.sol", optimizer = true, via_ir = true, optimizer_runs = 22_300 },
  { paths = "src/spoke/instances/SpokeInstance.sol", optimizer = true, via_ir = true, optimizer_runs = 750 },
  { paths = "tests/**", optimizer = true, via_ir = false, optimizer_runs = 444444444444 },
  { paths = "scripts/**", optimizer = true, via_ir = false, optimizer_runs = 444444444444 },
]
```

Scripts import ONLY interfaces (IHub, ISpoke, ISpokeInstance). Concrete bytecode loaded via `vm.getCode()`.

## Output (`output/deploy.json`)

Written by `logAddy()`. Structure:

```jsonc
{
  "admin": "0x...",
  "accessManager": "0x...",
  "hub": { "HUB_KEY": "0x...", ... },
  "irStrategy": { "HUB_KEY": "0x...", ... },
  "treasury": { "HUB_KEY": "0x...", ... },
  "spoke": { "SPOKE_KEY": "0x...", ... },
  "oracle": { "SPOKE_KEY": "0x...", ... },
  "token": { "TOKEN_KEY": "0x...", ... },
  "tokenized": { "WETH_PRIME": "0x...", ... },
  "signatureGateway": "0x...",
  "nativeTokenGateway": "0x...",
  "hubConfigurator": "0x...",
  "spokeConfigurator": "0x...",
  "commit": "abc123..."
}
```

`load()` restores all of these into in-memory state for use by `debug()`, `seed()`, and `deployConfigurator()`.

### Tokenization Spokes

Auto-generated ERC4626 vaults deployed for each asset in `assets[]`. Controlled by `defaults.tokenize.enabled` (default: true) with per-asset override via `assets[].tokenize.enabled`. These do NOT appear in the `spokes[]` config array.

- **Key pattern**: `TOKENIZED_{tokenKey}_{hubPrefix}` where hubPrefix = hubKey minus `_HUB` suffix (e.g., `TOKENIZED_WETH_PRIME`)
- **deploy.json key**: `{tokenKey}_{hubPrefix}` under `tokenized` object (e.g., `WETH_PRIME`)
- **ERC20 naming**: name = `"{hubPrefix} {tokenKey}"` (e.g., "PRIME WETH"), symbol = `"t{tokenKey}-{hubPrefix}"` (e.g., "tWETH-PRIME")
- **Supply-only**: drawCap is hardcoded 0; validator errors (E19) if `tokenize.drawCap` is set non-zero
- **Deployment**: `new TokenizationSpokeInstance(hub, assetId)` wrapped in TransparentUpgradeableProxy (no CREATE2, no library linking)
- **Hub registration**: `hub.addSpoke(assetId, ts, SpokeConfig{addCap, drawCap:0, riskPremiumThreshold:0, active:true, halted:false})`

## CREATE2 and Redeployment

Hubs and SpokeInstances are deployed via CREATE2. On persistent forks (anvil/Tenderly), same inputs = same address. `create2Deploy` returns the existing contract if code already exists at the computed address.

- **Hub salt**: `keccak256(abi.encodePacked(hubKey))` — each hub gets a unique address
- **SpokeInstance salt**: empty bytes32 — all spokes get unique addresses because oracle address differs in constructor args

If redeploying on a persistent fork without resetting, the CREATE2 contracts will be reused from the previous run. This can cause `UnderlyingAlreadyListed` reverts if assets were already added to the hub. Fix: reset the fork or use different salts.

## Mock Price Feeds

Tokens with `priceFeed: "0x0000...0000"` in JSON get mock Chainlink feeds deployed at runtime. Currently hardcoded in `_deployMockPriceFeeds()` for wstETH and LDO. Remove when real feeds are available.

## Hub-Spoke Architecture

### Core Contracts

| Contract | Inheritance | Purpose |
|----------|-------------|---------|
| `Hub` (`src/hub/Hub.sol`) | `IHub`, `AccessManaged` | Manages assets and per-asset spoke registrations. Non-upgradeable. |
| `Spoke` (`src/spoke/Spoke.sol`) | `ISpoke`, `SpokeStorage`, `AccessManagedUpgradeable`, ... | Abstract. Manages reserves, user positions, and liquidations. Upgradeable via proxy. |
| `SpokeInstance` | `Spoke` | Concrete spoke implementation with `initialize()`. Deployed via CREATE2 + TransparentUpgradeableProxy. |
| `TreasurySpoke` (`src/spoke/TreasurySpoke.sol`) | `Ownable` | Fee receiver spoke. Supply-only, owner-gated. Not an `ISpoke`. |
| `TokenizationSpoke` (`src/spoke/TokenizationSpoke.sol`) | ERC4626 | ERC4626 vault wrapper for hub assets. Supply-only, no risk management. |

### Data Relationships

```
Hub
├── _assetCount (uint256) — sequential counter, assetId = _assetCount++
├── _assets[assetId] → Asset struct (liquidity, shares, indices, config)
├── _spokes[assetId][spokeAddr] → SpokeData struct (shares, caps, status)
├── _assetToSpokes[assetId] → EnumerableSet of spoke addresses
└── _underlyingToAssetId[tokenAddr] → assetId (enforces uniqueness)

Spoke
├── _reserveCount (uint256) — sequential counter, reserveId = _reserveCount++
├── _reserves[reserveId] → Reserve struct {underlying, hub, assetId, decimals, flags, ...}
├── _hubAssetIdToReserveId[hub][assetId] → reserveId
├── _dynamicConfig[reserveId][configKey] → DynamicReserveConfig (historied)
├── _userPositions[user][reserveId] → UserPosition struct
├── _positionStatus[user] → PositionStatus (bitmap of collateral/borrow flags + riskPremium)
├── _positionManager[pmAddr] → PositionManagerConfig {active, approval[user]}
└── _liquidationConfig → LiquidationConfig (spoke-wide)
```

### Key Struct Fields

**Hub.Asset**: `liquidity`, `addedShares`, `drawnShares`, `premiumShares`, `drawnIndex`, `drawnRate`, `decimals`, `underlying`, `irStrategy`, `feeReceiver`, `liquidityFee`, `reinvestmentController`, `deficitRay`, `realizedFees`, `swept`

**Hub.SpokeData**: `addedShares`, `drawnShares`, `premiumShares`, `addCap` (uint40, whole tokens), `drawCap` (uint40), `riskPremiumThreshold` (uint24 BPS), `active`, `halted`, `deficitRay`

**Hub.SpokeConfig**: `addCap`, `drawCap`, `riskPremiumThreshold`, `active`, `halted` (subset of SpokeData for add/update)

**Spoke.Reserve**: `underlying`, `hub` (IHubBase), `assetId` (uint16), `decimals`, `collateralRisk` (uint24 BPS), `flags` (packed bools), `dynamicConfigKey` (uint32)

**Spoke.DynamicReserveConfig**: `collateralFactor` (uint16 BPS), `maxLiquidationBonus` (uint32 BPS), `liquidationFee` (uint16 BPS). Historied — new keys added via `addDynamicReserveConfig()`, old keys immutable for existing user positions.

**Spoke.UserPosition**: `suppliedShares`, `drawnShares`, `premiumShares`, `premiumOffsetRay`, `dynamicConfigKey`

### Cross-Hub Borrowing Pattern

A spoke can be registered on **multiple hubs** for different assets. Example from `config/mainnet.json`:
- `ETHENA_SPOKE` registered on `ETHENA_HUB` for sUSDe, PT_sUSDe, USDC, USDT, GHO
- `ETHENA_SPOKE` also registered on `CORE_HUB` for USDC (cross-hub)

On the spoke side, each (hub, assetId) pair maps to a unique `reserveId`. The spoke stores `_hubAssetIdToReserveId[hub][assetId] → reserveId`, and each `Reserve` stores the `hub` and `assetId` references.

### Fee Receiver Auto-Registration

When `hub.addAsset()` is called, the `feeReceiver` address (typically a `TreasurySpoke`) is automatically registered as a spoke on that asset via `_addFeeReceiver()` with config: `addCap=type(uint40).max, drawCap=0, riskPremiumThreshold=0, active=true, halted=false`.

### Oracle Architecture

Each spoke has its own `AaveOracle` (`src/spoke/AaveOracle.sol`):
- Immutable: `DECIMALS` (uint8), `DESCRIPTION` (string), `SPOKE` (address, set once via `setSpoke()`)
- Stores `_sources[reserveId] → AggregatorV3Interface` (Chainlink price feed per reserve)
- `setReserveSource()` called only by the spoke (during `addReserve()` via `_updateReservePriceSource()`)
- `getReservePrice(reserveId)` returns price with `DECIMALS` precision

### Position Manager System

Position managers are delegates that can act on behalf of users. Two-layer check:
1. **Global activation**: Admin calls `spoke.updatePositionManager(pm, true)` (sets `_positionManager[pm].active = true`)
2. **Per-user approval**: User calls `spoke.setUserPositionManager(pm, true)` (sets `_positionManager[pm].approval[user] = true`)

Both must be true for `_isPositionManager(user, pm)` to return true. Gateways (SignatureGateway, NativeTokenGateway) are registered as position managers on each spoke.

### Access Control Flow

```
AccessManager (single instance)
  │
  ├─ grantRole(roleId, account, delay) — who has which role
  │
  └─ setTargetFunctionRole(target, selectors, roleId) — which role can call which function
      │
      └─ Hub/Spoke use `restricted` modifier from AccessManaged/AccessManagedUpgradeable
          └─ calls AccessManager.canCall(msg.sender, target, msg.sig) before execution
```

## Deployment Validation Test

`tests/DeployValidation.t.sol` validates that on-chain state matches the source configuration. It reads expected values from `config/<network>.json` (via `ConfigReader`) and deployed addresses from `output/deploy.json` (via `DeployReader`), then calls view functions on every deployed contract to assert correctness.

### What It Validates (13 tests)

| Test | Validates |
|------|-----------|
| `test_hubAssets` | Asset listings, decimals, feeReceiver, irStrategy, liquidityFee, all IR parameters |
| `test_spokeRegistrations` | Spoke-to-hub registrations: addCap, drawCap, riskPremiumThreshold, active, halted |
| `test_treasurySpokeRegistrations` | Treasury auto-registration on every hub asset (addCap=max, drawCap=0) |
| `test_reserves` | Reserve data, ReserveConfig (borrowable, collateralRisk, paused, frozen, receiveSharesEnabled), DynamicReserveConfig (collateralFactor, maxLiquidationBonus, liquidationFee) |
| `test_liquidationConfigs` | Per-spoke liquidation parameters: targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor |
| `test_oracleSetup` | Oracle↔spoke linkage, oracle decimals, per-reserve price sources (skips mock feeds), price > 0 |
| `test_positionManagers` | SignatureGateway and NativeTokenGateway registered as active position managers on each spoke |
| `test_accessControlRoles` | Admin has HUB_ADMIN + SPOKE_ADMIN; configurators have their respective admin roles |
| `test_accessControlHubSelectors` | 6 Hub selectors → HUB_ADMIN_ROLE, eliminateDeficit → DEFICIT_ELIMINATOR_ROLE |
| `test_accessControlSpokeSelectors` | 7 Spoke selectors → SPOKE_ADMIN_ROLE, 2 selectors → USER_POSITION_UPDATER_ROLE |
| `test_accessControlConfiguratorSelectors` | 22 HubConfigurator selectors → HUB_CONFIGURATOR_ROLE, 25 SpokeConfigurator selectors → SPOKE_CONFIGURATOR_ROLE |
| `test_tokenizationSpokes` | ERC4626 vault registration, hub/assetId references, ERC20 name/symbol, SpokeConfig (drawCap=0, riskPremiumThreshold=0) |
| `test_authority` | All hubs, spokes, and configurators point to the same AccessManager |

### Helper Library: `tests/DeployReader.sol`

Stateless library for reading `output/deploy.json`. Mirrors the `ConfigReader` pattern. Functions: `admin`, `accessManager`, `signatureGateway`, `nativeTokenGateway`, `hubConfigurator`, `spokeConfigurator`, `hub(hubKey)`, `irStrategy(hubKey)`, `treasury(hubKey)`, `spoke(spokeKey)`, `oracle(spokeKey)`, `token(tokenKey)`, `tokenized(tsKey)`.

### Running

```bash
# Against local anvil
forge test --match-contract DeployValidation --fork-url http://localhost:8545 -vvv

# Against mainnet fork
forge test --match-contract DeployValidation --fork-url $RPC_MAINNET -vvv

# Custom config/deploy paths
CONFIG_PATH=config/testnet.json DEPLOY_PATH=output/deploy-testnet.json \
  forge test --match-contract DeployValidation --fork-url $RPC -vvv
```

### Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CONFIG_PATH` | `config/mainnet.json` | Path to expected configuration |
| `DEPLOY_PATH` | `output/deploy.json` | Path to deployed addresses |

## Known Limitations

- `_assetId()` helper does a linear scan of hub assets by underlying address. Does not work if the same token is listed multiple times on the same hub.
- FfiUtils helpers in `SpokeDeployUtils.sol` require `cast` CLI to be installed (for `cast abi-encode`).
- `seed()` operations are randomized via `vm.randomUint()` — results vary per run.
