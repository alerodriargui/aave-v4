# scripts/deploy/

Modular deployment libraries for Aave V4. Each library is a self-contained phase of the deployment pipeline, operating on a shared `DeployReport` storage struct.

## Quick Start

```bash
# 1. Start anvil
anvil --fork-url $RPC_MAINNET

# 2. Deploy LiquidationLogic library (required before main deploy)
forge script scripts/LibraryPreCompile.s.sol \
  --broadcast --rpc-url anvil \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked --slow --legacy --offline

# 3. Run the full deployment
forge script scripts/deploy/Deploy.s.sol:DeployV4 \
  --broadcast --rpc-url anvil \
  -s "run()" \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked --slow --legacy --offline

# 4. Validate deployment
forge test --match-contract DeployValidation --rpc-url anvil --offline -vvv
```

To deploy with a different config (e.g. `config/generated.json`):

```bash
# Deploy
CONFIG_PATH=config/generated.json forge script scripts/deploy/Deploy.s.sol:DeployV4 \
  --broadcast --rpc-url anvil -s "run()" \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --unlocked --slow --legacy --offline

# Validate
CONFIG_PATH=config/generated.json forge test --match-contract DeployValidation \
  --rpc-url anvil --offline -vvv
```

Deployed addresses are written to `output/deploy.json`. Structured logs go to `output/deploy.log.jsonl`.

## Config Generator (`scripts/generate-config.ts`)

Parses an Excel spreadsheet (`configIn/v4 initial config.xlsx`) and produces a validated JSON config file consumable by the Solidity deploy scripts.

```bash
# Default: reads configIn/v4 initial config.xlsx, writes config/generated.json
bun scripts/generate-config.ts

# Custom paths
bun scripts/generate-config.ts "configIn/v4 initial config.xlsx" config/generated.json
```

### Excel Structure

The script expects a workbook with 4 sheets:

| Sheet        | Contents                                                                                                       |
| ------------ | -------------------------------------------------------------------------------------------------------------- |
| `Hub Assets` | Master asset list: columns Asset, Hub, Category. One row per (token, hub) pair.                                |
| `Prime`      | Spoke reserve matrix for PRIME_HUB: spoke definitions (name, e-mode, credit line) + collateral/borrowable grid |
| `Core`       | Spoke reserve matrix for CORE_HUB (same format)                                                                |
| `Plus`       | Spoke reserve matrix for PLUS_HUB (same format)                                                                |

Each spoke sheet has two sections:

1. **Spoke definitions** — rows with Spokes / e-Mode / Credit Line From columns, listing which spokes exist for that hub
2. **Reserve matrix** — Hub + Assets columns, then (Collateral, Borrowable) column pairs per spoke, marked with "X"

### What It Generates

From the parsed data, the script builds a complete config JSON:

| Section              | Source                                                                                          |
| -------------------- | ----------------------------------------------------------------------------------------------- |
| `tokens`             | `TOKEN_REGISTRY` — hardcoded mainnet addresses + Chainlink price feeds for all 22 tokens        |
| `hubs`               | Fixed: `[PRIME_HUB, CORE_HUB, PLUS_HUB]`                                                        |
| `spokes`             | Deduplicated from all 3 spoke sheets, with liquidation config profiles per spoke type           |
| `assets`             | One per unique (tokenKey, hubKey) from Hub Assets sheet + cross-hub entries from reserve matrix |
| `spokeRegistrations` | One per (tokenKey, hubKey, spokeKey) from reserve matrix, with estimated supply/borrow caps     |
| `reserves`           | One per (spokeKey, hubKey, tokenKey), with profile-based risk parameters                        |
| `defaults`           | Mirrors `ConfigReader.sol` defaults (liquidation config, spoke registration, reserve, tokenize) |
| `periphery`          | `{ nativeTokenKey: "WETH", deploySignatureGateway: true, deployNativeTokenGateway: true }`      |

### Key Normalization

Excel names are mapped to config keys:

- **Tokens**: `wETH→WETH`, `wBTC→WBTC`, `cBTC→cbBTC`, `frx USD→frxUSD`, `PT-sUSDEs→PT_sUSDe`, `PT-USDEs→PT_USDe`
- **Hubs**: `Prime→PRIME_HUB`, `Core→CORE_HUB`, `Plus→PLUS_HUB`
- **Spokes**: `Bluechip Spoke→BLUECHIP_SPOKE`, `Lido e-Spoke→LIDO_ESPOKE`, etc.

### Profile-Based Parameters

Reserve parameters are assigned by profile rather than per-asset, based on token category and spoke context:

| Profile           | CF   | Risk | MaxLiqBonus | Used for                          |
| ----------------- | ---- | ---- | ----------- | --------------------------------- |
| `stable_col_bor`  | 8300 | 0    | 10000       | Stablecoin collateral+borrowable  |
| `stable_bor_only` | 0    | 0    | 10000       | Stablecoin borrow-only            |
| `eth_col_bor`     | 8500 | 0    | default     | WETH collateral+borrowable        |
| `emode_lst_col`   | 9300 | 0    | 10600       | LST in e-mode spoke (liqFee=1500) |
| `ethena_col`      | 8000 | 900  | 10600       | sUSDe/USDe collateral-only        |

IR strategy profiles (stablecoin, eth, lst, btc, gov, gold, ethena_yield, ethena_pt) determine interest rate parameters per asset.

Cap estimates are heuristic-based by category:

- Major stables: addCap=3M, drawCap=2.76M
- GHO: addCap=17.5M, drawCap=15M
- WETH (main): addCap=800, drawCap=725
- LSTs (e-mode): addCap=200, drawCap=0

### Cross-Hub Borrowing

When a spoke sheet has "Credit Line From: Core Hub", the rows with `Hub=Core` generate cross-hub entries: a spoke registration linking the spoke to CORE_HUB, and a reserve with borrow-only profile (CF=0, maxLiqBonus=10000, liqFee=0).

### Validation

The generator imports `validate` from `validate-config.ts` and runs it on the assembled config before writing. Exits with code 1 if any errors. Current output: 0 errors, 1 warning (rsETH mock price feed).

## Config Validator (`scripts/validate-config.ts`)

Validates a config JSON file against the schema and business rules. Exported `validate(raw)` function returns `{ errors, warnings }`.

```bash
# Validate a config file
bun scripts/validate-config.ts config/mainnet.json
bun scripts/validate-config.ts config/generated.json

# Run validator unit tests
bun test scripts/validate-config.test.ts
```

### Validation Phases

**Phase 1: Schema** — Zod strict parsing of all JSON structure. Every object uses `.strict()` so unknown keys are rejected.

**Phase 2: Referential integrity + constraints** — business logic checks on parsed data.

### Error Codes

| Code     | Check                                                          |
| -------- | -------------------------------------------------------------- |
| `SCHEMA` | Zod schema violation (wrong type, missing required field)      |
| `E1`     | `tokenKey`/`assetKey` not found in `tokens`                    |
| `E2`     | `hubKey` not found in `hubs`                                   |
| `E3`     | `spokeKey` not found in `spokes`                               |
| `E4`     | Duplicate asset (same tokenKey+hubKey)                         |
| `E5`     | Duplicate spoke registration                                   |
| `E6`     | Duplicate reserve                                              |
| `E7`     | Spoke registration references non-existent asset               |
| `E8`     | Reserve references non-existent asset                          |
| `E9`     | Reserve without matching spoke registration                    |
| `E10`    | `collateralFactor >= 10000`                                    |
| `E11`    | `maxLiquidationBonus < 10000`                                  |
| `E12`    | `percentMulUp(maxLiquidationBonus, collateralFactor) >= 10000` |
| `E13`    | `liquidationFee > 10000`                                       |
| `E14`    | `liquidityFee > 10000`                                         |
| `E15`    | `collateralRisk > 100000`                                      |
| `E16`    | `optimalUsageRatio > 10000`                                    |
| `E17`    | `periphery.nativeTokenKey` not in tokens                       |
| `E18`    | `borrowable=true` but `drawCap=0`                              |
| `E19`    | `tokenize.drawCap != 0` (tokenization spokes are supply-only)  |
| `E20`    | Unknown key in any object (via Zod strict mode)                |

### Warning Codes

| Code | Check                                                                             |
| ---- | --------------------------------------------------------------------------------- |
| `W2` | `collateralFactor > 0` but `addCap=0` (collateral enabled but no supply possible) |
| `W3` | `drawCap > 0` but reserve `borrowable=false`                                      |
| `W4` | `collateralFactor=0` and `borrowable=false` (reserve serves no purpose)           |
| `W6` | Spoke registration exists but no reserve on the spoke                             |
| `W7` | Token with mock price feed (`0x0`) used in reserves                               |

### Test Suite (`scripts/validate-config.test.ts`)

60 tests covering every error and warning code. Uses `bun:test`. Key test groups:

- **Baseline**: minimal clean config produces no errors; production `mainnet.json` has no errors
- **E1-E3**: Invalid token/hub/spoke references in assets, spokeRegistrations, reserves
- **E4-E6**: Duplicate detection for assets, spoke registrations, reserves
- **E7-E9**: Missing cross-references (asset for spoke reg, asset for reserve, spoke reg for reserve)
- **E10-E16**: Numeric constraint violations (collateralFactor, maxLiquidationBonus, liquidationFee, liquidityFee, collateralRisk, optimalUsageRatio)
- **E17**: Invalid periphery.nativeTokenKey
- **E18**: Borrowable with zero drawCap
- **E19**: Non-zero drawCap on tokenization spokes
- **E20**: Unknown keys at every nesting level (20 test cases)
- **SCHEMA**: Type errors (string where number expected, missing required fields)
- **W2-W7**: Warning scenarios with positive and negative cases

## Architecture

```
Deploy.s.sol:DeployV4.run()
│
├── Phase 1: Infrastructure
│   ├── DeployInfra.setUpTokens()             ─── tokens + mock price feeds
│   └── DeployInfra.deployInfrastructure()     ─── AccessManager, spokes (oracle + SpokeInstance), hubs (Hub + TreasurySpoke + IRStrategy)
│
├── Phase 2: Roles
│   └── DeployPeriphery.setUpRoles()           ─── AccessManager selector→role mappings for all hubs/spokes
│
├── Phase 3: Market Configuration
│   └── DeployMarket.configureMarkets()        ─── asset listing (hub.addAsset), spoke registration (hub.addSpoke), tokenization spokes
│
├── Phase 4: Reserves
│   └── DeployPeriphery.setUpReserves()        ─── spoke.addReserve + liquidation configs
│
├── Phase 5: Gateways
│   └── DeployPeriphery.deployGateways()       ─── SignatureGateway + NativeTokenGateway + PM registration
│
├── Phase 6: Configurators
│   └── DeployPeriphery.deployConfigurators()  ─── HubConfigurator + SpokeConfigurator + Level 1+2 role setup
│
└── ReportIO.writeReport()                     ─── serialize DeployReport to output/deploy.json
```

All libraries use `internal` functions with `DeployReport storage` as the first parameter. Since internal library functions execute via DELEGATECALL in the caller's context, they read/write the caller's storage directly.

## Files

| File                  | Public Functions                                                       | Purpose                                                                                                                                                                                    |
| --------------------- | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Deploy.s.sol`        | `run`, `load`                                                          | Entry point contract (`DeployV4`). `run()` for full deployment, `load()` for restoring state from deploy.json                                                                              |
| `DeployTypes.sol`     | —                                                                      | `DeployReport` struct, sub-report structs (`HubReport`, `SpokeReport`, `TokenReport`, `TokenizationReport`), `DeployReportLib` finder/push helpers                                         |
| `DeployInfra.sol`     | `setUpTokens`, `deployInfrastructure`                                  | Tokens (+ mock feeds for `priceFeed=0x0`), AccessManager, spokes (AaveOracle + SpokeInstance via CREATE2), hubs (Hub via CREATE2 + TreasurySpoke + AssetInterestRateStrategy)              |
| `DeployMarket.sol`    | `configureMarkets`                                                     | Asset listing (`hub.addAsset` + IR data), spoke registration (`hub.addSpoke` with SpokeConfig), tokenization spoke deployment (ERC4626 vaults via TransparentUpgradeableProxy)             |
| `DeployPeriphery.sol` | `setUpRoles`, `setUpReserves`, `deployGateways`, `deployConfigurators` | AccessManager role mappings, reserve listing + liquidation configs, SignatureGateway + NativeTokenGateway + PM registration, HubConfigurator + SpokeConfigurator with Level 1+2 role setup |
| `ReportIO.sol`        | `writeReport`, `readReport`                                            | Serialize `DeployReport` → JSON (`writeReport`), restore from `deploy.json` + config JSON (`readReport`)                                                                                   |

### Supporting Files (in `scripts/`)

| File                      | Purpose                                                                                                                                                                              |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ConfigReader.sol`        | Library for reading `config/<network>.json` with 3-level default resolution (per-item → `defaults` section → hardcoded constant)                                                     |
| `DeployLogger.sol`        | Dual-output logging: console + JSONL file (`output/deploy.log.jsonl`). Each event is a JSON object with `ts`, `event`, `data` fields                                                 |
| `DeployReader.sol`        | Library for reading `output/deploy.json` addresses via `stdJson`. Functions: `admin`, `accessManager`, `hub(key)`, `spoke(key)`, `oracle(key)`, `token(key)`, `tokenized(key)`, etc. |
| `ScriptUtils.sol`         | Shared utilities: `strEq()` (string equality), `assetId(hub, token)` (linear scan), `slice()`, `commit()` (git hash via FFI)                                                         |
| `SpokeDeployUtils.sol`    | SpokeInstance deployment via CREATE2 with LiquidationLogic library linking. Also manages `FOUNDRY_LIBRARIES` in `.env`                                                               |
| `LibraryPreCompile.s.sol` | Prerequisite script: deploys LiquidationLogic via CREATE2, writes `FOUNDRY_LIBRARIES` to `.env`                                                                                      |
| `validate-config.ts`      | TypeScript + Zod config validator: schema validation, referential integrity, constraint violations, warnings                                                                         |
| `generate-config.ts`      | TypeScript Excel→JSON generator: parses `configIn/*.xlsx` spreadsheet and produces a validated `config/generated.json`                                                               |

## DeployReport

Single struct that replaces all the mappings + arrays in the old monolithic script:

```solidity
struct DeployReport {
  address admin;
  address accessManager;
  address signatureGateway;
  address nativeTokenGateway;
  address hubConfigurator;
  address spokeConfigurator;
  string commit;
  HubReport[] hubs; // key, hub, treasury, irStrategy
  SpokeReport[] spokes; // key, spoke, oracle
  TokenReport[] tokens; // key, token, priceFeed
  TokenizationReport[] tokenized; // key, spoke (ERC4626 vault)
}
```

`DeployReportLib` provides finder helpers (`findHub`, `findSpoke`, `findToken`, `findTokenized`) and push methods. Finders do linear scans by key — fine for small arrays. All finders revert with descriptive messages on miss.

## Config Toolchain

| Tool                         | Purpose                                                                                                                                         |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `config/mainnet.json`        | Hand-authored reference config for mainnet                                                                                                      |
| `config/generated.json`      | Machine-generated config from Excel spreadsheet                                                                                                 |
| `scripts/generate-config.ts` | Parses `configIn/*.xlsx` → validated JSON config. Usage: `bun scripts/generate-config.ts [xlsx-path] [output-path]`                             |
| `scripts/validate-config.ts` | Zod schema + referential integrity + constraint validation. Usage: `bun scripts/validate-config.ts [config-path]`                               |
| `scripts/ConfigReader.sol`   | Solidity library for reading config JSON at deploy time. 3-level default resolution: per-item field → `defaults.*` section → hardcoded constant |

### Config Schema Overview

```jsonc
{
  "defaults": { /* spoke, spokeRegistration, reserve, asset, tokenize defaults */ },
  "tokens":   { "KEY": { "address": "0x...", "priceFeed": "0x..." } },
  "hubs":     [{ "key": "HUB_NAME" }],
  "spokes":   [{ "key": "SPOKE_NAME", "liquidationConfig": { ... } }],
  "assets":   [{ "tokenKey": "KEY", "hubKey": "HUB_NAME", "irData": { ... } }],
  "spokeRegistrations": [{ "assetKey": "KEY", "hubKey": "HUB_NAME", "spokeKey": "SPOKE_NAME", "addCap": N, "drawCap": N }],
  "reserves": [{ "spokeKey": "SPOKE_NAME", "hubKey": "HUB_NAME", "assetKey": "KEY", "borrowable": bool, "collateralFactor": N, ... }],
  "periphery": { "nativeTokenKey": "WETH", "deploySignatureGateway": true, "deployNativeTokenGateway": true }
}
```

Full schema documentation is in `CLAUDE.md`.

## Environment Variables

| Variable      | Default                   | Purpose                               |
| ------------- | ------------------------- | ------------------------------------- |
| `CONFIG_PATH` | `config/mainnet.json`     | Path to deployment configuration JSON |
| `DEPLOY_PATH` | `./output/deploy.json`    | Path for deploy report output / input |
| `LOG_PATH`    | `output/deploy.log.jsonl` | Path for structured JSONL deploy log  |

## Load Existing Deployment

```solidity
function load() public {
  string memory json = vm.readFile(
    vm.envOr("CONFIG_PATH", string("config/mainnet.json"))
  );
  string memory deployPath = vm.envOr(
    "DEPLOY_PATH",
    string("./output/deploy.json")
  );
  ReportIO.readReport(report, deployPath, json);
}
```

`readReport` reads deployed addresses from `deploy.json` and cross-references config JSON to reconstruct full token/hub/spoke/tokenization data.

## Prerequisites

1. **LiquidationLogic**: Must be pre-deployed via `LibraryPreCompile.s.sol`. Writes `FOUNDRY_LIBRARIES=src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:0xADDR` to `.env`. Main deploy checks for this and reverts with a clear message if not found.
2. **Config validation**: Run `bun scripts/validate-config.ts config/mainnet.json` (or your config path) before deploying. Zero errors required; warnings for mock price feeds are acceptable.
3. **`cast` CLI**: Required for FFI calls in `SpokeDeployUtils.sol` (ABI encoding, `.env` management).

## Post-Deployment Validation

`tests/DeployValidation.t.sol` reads expected values from config JSON (via `ConfigReader`) and deployed addresses from `output/deploy.json` (via `DeployReader`), then calls view functions on every deployed contract to assert correctness.

### 17 Test Functions

| Test                                      | Validates                                                                                                                                                                    |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `test_hubAssets`                          | Asset listings, decimals, feeReceiver, irStrategy, liquidityFee, all IR parameters                                                                                           |
| `test_spokeRegistrations`                 | Spoke-to-hub registrations: addCap, drawCap, riskPremiumThreshold, active, halted                                                                                            |
| `test_treasurySpokeRegistrations`         | Treasury auto-registration on every hub asset (addCap=max, drawCap=0)                                                                                                        |
| `test_reserves`                           | Reserve data, ReserveConfig (borrowable, collateralRisk, paused, frozen, receiveSharesEnabled), DynamicReserveConfig (collateralFactor, maxLiquidationBonus, liquidationFee) |
| `test_liquidationConfigs`                 | Per-spoke liquidation parameters: targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor                                                                        |
| `test_spokeImmutables`                    | Spoke immutable properties: MAX_USER_RESERVES_LIMIT, ORACLE address                                                                                                          |
| `test_oracleSetup`                        | Oracle↔spoke linkage, oracle decimals, per-reserve price sources (skips mock feeds), price > 0                                                                               |
| `test_positionManagers`                   | SignatureGateway and NativeTokenGateway registered as active position managers on each spoke                                                                                 |
| `test_accessControlRoles`                 | Admin has HUB_ADMIN + SPOKE_ADMIN; configurators have their respective admin roles                                                                                           |
| `test_accessControlHubSelectors`          | 6 Hub selectors → HUB_ADMIN_ROLE, eliminateDeficit → DEFICIT_ELIMINATOR_ROLE                                                                                                 |
| `test_accessControlSpokeSelectors`        | 7 Spoke selectors → SPOKE_ADMIN_ROLE, 2 selectors → USER_POSITION_UPDATER_ROLE                                                                                               |
| `test_accessControlConfiguratorSelectors` | 22 HubConfigurator selectors → HUB_CONFIGURATOR_ROLE, 25 SpokeConfigurator selectors → SPOKE_CONFIGURATOR_ROLE                                                               |
| `test_tokenizationSpokes`                 | ERC4626 vault registration, hub/assetId references, ERC20 name/symbol, SpokeConfig (drawCap=0, riskPremiumThreshold=0)                                                       |
| `test_hubAssetCounts`                     | On-chain asset count per hub matches config                                                                                                                                  |
| `test_spokeCountsPerAsset`                | Spoke count per (hub, asset) pair matches expected (treasury + spoke registrations + tokenization spokes)                                                                    |
| `test_reserveCountsPerSpoke`              | Reserve count per spoke matches config                                                                                                                                       |
| `test_authority`                          | All hubs, spokes, and configurators point to the same AccessManager                                                                                                          |

### Running

```bash
# Default config (config/mainnet.json)
forge test --match-contract DeployValidation --rpc-url anvil --offline -vvv

# Custom config
CONFIG_PATH=config/generated.json forge test --match-contract DeployValidation --rpc-url anvil --offline -vvv

# Custom config + deploy paths
CONFIG_PATH=config/testnet.json DEPLOY_PATH=output/deploy-testnet.json \
  forge test --match-contract DeployValidation --fork-url $RPC -vvv
```

## Compilation

These libraries compile under the `scripts/**` restriction in `foundry.toml` (optimizer on, via_ir off, runs=444444444444). They import only interfaces from `src/` — concrete bytecode is loaded via `vm.getCode()` at runtime.

Never use `forge build --force` — full recompilation is extremely slow due to via-IR compilation of Hub and SpokeInstance. Forge's incremental compilation handles changes correctly.

## Mock Price Feeds

Tokens with `priceFeed: "0x0000...0000"` in config JSON get mock Chainlink feeds deployed at runtime by `DeployInfra._deployMockPriceFeeds()`. Currently hardcoded for:

| Token  | Mock Price           | Note    |
| ------ | -------------------- | ------- |
| wstETH | 550429206740 (8 dec) | ~$5,504 |
| LDO    | 85721424 (8 dec)     | ~$0.86  |
| rsETH  | 202154210329 (8 dec) | ~$2,022 |

Remove mock entries when real Chainlink feeds are available.

## Output (`output/deploy.json`)

Written by `ReportIO.writeReport()`. Structure:

```jsonc
{
  "admin": "0x...",
  "accessManager": "0x...",
  "hub": { "PRIME_HUB": "0x...", "CORE_HUB": "0x...", ... },
  "irStrategy": { "PRIME_HUB": "0x...", ... },
  "treasury": { "PRIME_HUB": "0x...", ... },
  "spoke": { "BLUECHIP_SPOKE": "0x...", "MAIN_SPOKE": "0x...", ... },
  "oracle": { "BLUECHIP_SPOKE": "0x...", ... },
  "token": { "WETH": "0x...", "WBTC": "0x...", ... },
  "tokenized": { "WETH_PRIME": "0x...", ... },
  "signatureGateway": "0x...",
  "nativeTokenGateway": "0x...",
  "hubConfigurator": "0x...",
  "spokeConfigurator": "0x...",
  "commit": "abc123..."
}
```
