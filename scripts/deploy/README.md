# scripts/deploy/

Modular deployment libraries for Aave V4. Each library is a self-contained phase of the deployment pipeline, operating on a shared `DeployReport` storage struct.

## Quick Start

```bash
# 1. Start anvil
anvil

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
forge test --match-contract DeployValidation --rpc-url anvil -vvv
```

Deployed addresses are written to `output/deploy.json`.

## Architecture

```
Deploy.s.sol:DeployV4 (entry point)
│
├── DeployInfra.setUpTokens()           ─── tokens + mock feeds
├── DeployInfra.deployInfrastructure()  ─── AccessManager, spokes, hubs
│
├── DeployPeriphery.setUpRoles()        ─── AccessManager selector→role mappings
│
├── DeployMarket.configureMarkets()     ─── asset listing, spoke reg, tokenization
│
├── DeployPeriphery.setUpReserves()     ─── reserves + liquidation configs
├── DeployPeriphery.deployGateways()    ─── SignatureGateway + NativeTokenGateway
├── DeployPeriphery.deployConfigurators() ─ HubConfigurator + SpokeConfigurator
│
└── ReportIO.writeReport()              ─── serialize to output/deploy.json
```

All libraries use `internal` functions with `DeployReport storage` as the first parameter. Since internal library functions execute via DELEGATECALL in the caller's context, they read/write the caller's storage directly.

## Files

| File | Public Functions | Purpose |
|------|-----------------|---------|
| `Deploy.s.sol` | `run`, `load` | Entry point contract (`DeployV4`) |
| `DeployTypes.sol` | — | `DeployReport` struct, sub-report structs, `DeployReportLib` finder/push helpers |
| `DeployInfra.sol` | `setUpTokens`, `deployInfrastructure` | Tokens, AccessManager, spokes (oracle + SpokeInstance), hubs (Hub + TreasurySpoke + IRStrategy) |
| `DeployMarket.sol` | `configureMarkets` | Asset listing (`hub.addAsset`), spoke registration (`hub.addSpoke`), tokenization spoke deployment |
| `DeployPeriphery.sol` | `setUpRoles`, `setUpReserves`, `deployGateways`, `deployConfigurators` | AccessManager roles, reserves, liquidation configs, gateways, PM registration, configurator deployment |
| `ReportIO.sol` | `writeReport`, `readReport` | Serialize `DeployReport` to JSON / restore from JSON + config |

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
  HubReport[] hubs;         // hub address + treasury + irStrategy
  SpokeReport[] spokes;     // spoke address + oracle
  TokenReport[] tokens;      // token address + priceFeed
  TokenizationReport[] tokenized;  // ERC4626 vault address
}
```

Finder helpers (`DeployReportLib`) do linear scans by key — fine for small arrays (4 hubs, 5 spokes, 15 tokens).

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `CONFIG_PATH` | `config/mainnet.json` | Path to deployment configuration |
| `DEPLOY_PATH` | `./output/deploy.json` | Path for deploy report output / input |

## Load Existing Deployment

```solidity
function load() public {
    string memory json = vm.readFile(vm.envOr('CONFIG_PATH', string('config/mainnet.json')));
    string memory deployPath = vm.envOr('DEPLOY_PATH', string('./output/deploy.json'));
    ReportIO.readReport(report, deployPath, json);
}
```

## Prerequisites

1. LiquidationLogic must be pre-deployed via `LibraryPreCompile.s.sol` (writes `FOUNDRY_LIBRARIES` to `.env`)
2. Config JSON must pass validation: `bun scripts/validate-config.ts config/mainnet.json`

## Compilation

These libraries compile under the `scripts/**` restriction in `foundry.toml` (optimizer on, via_ir off). They import only interfaces from `src/` — concrete bytecode is loaded via `vm.getCode()` at runtime.

```bash
forge build
```
