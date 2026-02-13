# Config Engine

Stateless on-chain engines for configuring Aave V4 hubs and spokes through their respective Configurator contracts. Designed for both initial deployment setup and ongoing governance proposals.

## Overview

```
                    ┌───────────────────┐
                    │  Governance / EOA  │
                    └─────────┬─────────┘
                              │ calls execute()
                    ┌─────────▼─────────┐
                    │    Payload         │  (AaveV4HubPayload / AaveV4SpokePayload)
                    │    (per-proposal)  │
                    └─────────┬─────────┘
                              │ calls engine functions
             ┌────────────────┼────────────────┐
             ▼                                 ▼
  ┌─────────────────────┐          ┌─────────────────────────┐
  │  AaveV4HubConfigEngine │        │  AaveV4SpokeConfigEngine │
  │  (stateless)           │        │  (stateless)             │
  └──────────┬─────────────┘        └──────────┬──────────────┘
             │                                  │
             ▼                                  ▼
  ┌──────────────────┐              ┌────────────────────┐
  │  HubConfigurator  │             │  SpokeConfigurator  │
  │  (AccessManaged)  │             │  (AccessManaged)    │
  └──────────┬────────┘             └────────┬───────────┘
             │                               │
             ▼                               ▼
  ┌──────────────┐                  ┌──────────────┐
  │     Hub       │                 │    Spoke      │
  └──────────────┘                  └──────────────┘
```

## Components

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

### Role Requirements

The config engines need specific roles granted on AccessManager:

**HubConfigEngine** requires:

- `HUB_CONFIGURATOR_ADMIN_ROLE` (9) — for all listing and update operations

**SpokeConfigEngine** requires:

- `SPOKE_CONFIGURATOR_ADMIN_ROLE` (13) — for listing and admin-level reserve updates
- `SPOKE_FREEZE_ROLE` (14) — for `updateFrozen` on reserves
- `SPOKE_PAUSE_ROLE` (15) — for `updatePaused` on reserves

## Governance Payloads

Abstract payload contracts provide a hook-based pattern for creating governance proposals.

### AaveV4PayloadBase

Shared base with `execute()` → `_preExecute()` → `_executePayload()` → `_postExecute()`.

### AaveV4HubPayload

Override virtual hooks to populate data for a Hub proposal:

```solidity
contract MyHubProposal is AaveV4HubPayload {
  constructor() AaveV4HubPayload(HUB, HUB_CONFIG_ENGINE) {}

  // Initial listings
  function newAssetListings() public pure override returns (AssetListing[] memory) { ... }
  function newSpokeListings() public pure override returns (SpokeListing[] memory) { ... }

  // Granular updates (override only what you need)
  function assetLiquidityFeeUpdates() public pure override returns (AssetLiquidityFeeUpdate[] memory) { ... }
  function assetIRDataUpdates() public pure override returns (AssetIRDataUpdate[] memory) { ... }
  function spokeCapUpdates() public pure override returns (SpokeCapUpdate[] memory) { ... }
  // ... etc
}
```

### AaveV4SpokePayload

```solidity
contract MySpokeProposal is AaveV4SpokePayload {
  constructor() AaveV4SpokePayload(HUB, SPOKE, SPOKE_CONFIG_ENGINE) {}

  function newReserveListings() public pure override returns (ReserveListing[] memory) { ... }
  function liquidationConfig() public pure override returns (LiquidationConfigInput memory) { ... }
  function reserveConfigUpdates() public pure override returns (ReserveConfigUpdate[] memory) { ... }
  function dynamicConfigUpdates() public pure override returns (DynamicConfigUpdate[] memory) { ... }
}
```

## ConfigReader

`scripts/ConfigReader.sol` — Library for parsing deployment JSON configs with 3-level default resolution.

### Default Resolution Order

For every configurable field:

1. **Per-item value** in the JSON array element
2. **Defaults section** value (`defaults.asset.*`, `defaults.reserve.*`, etc.)
3. **Hardcoded constant** in ConfigReader (e.g., `DEFAULT_LIQUIDITY_FEE = 1000`)

### Reader Functions

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

Each reader has a `*Strict` variant that reverts instead of falling back to defaults.

## Testing

```bash
# Config engine unit tests (22 tests — listing + granular updates)
forge test --match-path "tests/deployments/config-engine/AaveV4ConfigEngine*" -vvv

# ConfigReader scenario tests (79 tests across 9 scenarios)
forge test --match-path "tests/deployments/config-engine/ConfigReader*" -vvv
```

### Test Scenarios (in `config/test/`)

| Test File                            | Config File                              | What It Tests                                                   |
| ------------------------------------ | ---------------------------------------- | --------------------------------------------------------------- |
| `ConfigReader.t.sol`                 | `test-hub-spoke-2assets.json`            | Full API coverage: all reader functions, defaults, string utils |
| `ConfigReaderBasic.t.sol`            | `test-hub-spoke-no-tokenization.json`    | Global tokenization disabled, optional infra fields             |
| `ConfigReaderTokenization.t.sol`     | `test-hub-spoke-mixed-tokenization.json` | Per-item tokenize override, inherit, opt-out                    |
| `ConfigReaderMultiHub.t.sol`         | `test-2hubs-2spokes-cross-hub.json`      | Multiple hubs, cross-hub assets, per-spoke liquidation          |
| `ConfigReaderSingleAsset.t.sol`      | `test-single-asset.json`                 | Minimal config, single-item arrays                              |
| `ConfigReaderHubOnly.t.sol`          | `test-hub-only-no-assets.json`           | Empty arrays, bare hub deploy                                   |
| `ConfigReaderSpokeRegOnly.t.sol`     | `test-spoke-reg-only.json`               | Spoke expansion on existing hub                                 |
| `ConfigReaderAssetListingOnly.t.sol` | `test-asset-listing-only.json`           | Asset listing without spoke work                                |
| `ConfigReaderHub2Spokes.t.sol`       | `test-hub-2spokes-shared.json`           | 2 spokes sharing 1 hub, different configs                       |
