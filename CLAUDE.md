# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build
forge build              # Standard build
forge build --sizes      # Build with contract size output (or: make build)

# Test
forge test -vvv                              # Full test suite (or: make test)
forge test --match-contract MyContractTest   # Single test contract
forge test --match-test test_myFunction      # Single test function
forge test --match-path "tests/unit/Hub/*"   # Tests in a directory

# Lint
yarn lint                # Check formatting (Prettier + Solidity plugin)
yarn lint:fix            # Auto-fix formatting

# Gas & Coverage
make gas-report          # Gas snapshots (tests/gas/**)
make coverage            # Full lcov coverage report (uses FOUNDRY_PROFILE=coverage)

# Deployment
make deploy-full         # Full deploy via forge script (requires CHAIN, SENDER, ACCOUNT env vars)
```

## Foundry Profiles

- **default**: 1000 fuzz runs, `dynamic_test_linking = true`
- **pr**: 5000 fuzz runs (CI on pull requests)
- **ci**: 10000 fuzz runs (CI on merge to main)
- **coverage**: No via-ir, no dynamic linking, 50 fuzz runs

## Compilation Architecture

Hub.sol and SpokeInstance.sol compile with **via-ir** optimization (separate compiler profiles in foundry.toml). Tests compile without via-ir. This has critical implications:

- **Cannot use `new Hub()` or `new SpokeInstance()` from test code.** Use `vm.getCode()` + CREATE2 instead.
- `dynamic_test_linking = true` auto-deploys external libraries (like LiquidationLogic) during `forge test`, but NOT during `forge script`. Production deployment must handle library linking manually.
- `compilation_restrictions` in foundry.toml enforces which files use which compiler settings.

## Architecture

### Hub-and-Spoke Design

**Hub** (`src/hub/Hub.sol`): Central liquidity pool. Manages assets, interest rates, and liquidity across spokes. One Hub can serve multiple Spokes. Deployed via CREATE2 with via-ir.

**Spoke** (`src/spoke/Spoke.sol` / `src/spoke/instances/SpokeInstance.sol`): User-facing lending market. Handles supply, borrow, repay, withdraw, liquidation. Deployed behind TransparentUpgradeableProxy. Each Spoke connects to exactly one Hub.

**Flow**: User -> Spoke (position management) -> Hub (liquidity operations)

### Access Control

Uses OpenZeppelin `AccessManager` extended with enumeration (`src/access/AccessManagerEnumerable.sol`). Two-layer pattern:

1. **Selector-to-role mapping** on the target contract (e.g., `Hub.addAsset` -> `HUB_CONFIGURATOR_ROLE`)
2. **Role-to-account grant** (e.g., `HubConfigurator` address gets `HUB_CONFIGURATOR_ROLE`)
3. `restricted` modifier on functions checks `AccessManager.canCall(msg.sender, target, selector)`

**HubConfigurator** and **SpokeConfigurator** are admin wrapper contracts (also `AccessManaged`) that call through to Hub/Spoke restricted functions. Role IDs 0-15 defined in `src/deployments/utils/libraries/Roles.sol`.

### Deployment Infrastructure (`src/deployments/`)

```
Orchestration (AaveV4DeployOrchestration.sol)
  -> Batches (self-contained units deploying related contracts)
    -> Procedures (individual contract deploy/config/role functions)
      -> Create2Utils (deterministic CREATE2 deployment)
```

**Batches**: `AaveV4AuthorityBatch`, `AaveV4HubBatch`, `AaveV4SpokeInstanceBatch`, `AaveV4ConfiguratorBatch`, `AaveV4GatewayBatch`. Each deploys in its constructor and exposes `getReport()`.

**Config procedures**: `AaveV4HubConfigProcedures` (addAsset, addSpoke) and `AaveV4SpokeConfigProcedures` (addReserve, updateLiquidationConfig) wrap configurator calls.

### Config Engine (planned, `src/deployments/config-engine/`)

Split into two stateless engines for modularity:

- **AaveV4HubConfigEngine**: listAssets, addSpokes (including TokenizationSpoke deploy), updateAssets, updateSpokes → calls HubConfigurator (role 9)
- **AaveV4SpokeConfigEngine**: listReserves, updateLiquidationConfig, updateReserves, updateDynamicConfigs → calls SpokeConfigurator (role 13)

Three payload types: `AaveV4ListingPayload` (both engines, for first deployment), `AaveV4HubPayload` (hub-only), `AaveV4SpokePayload` (spoke-only). JSON configs in `config/hub/` and `config/spoke/`. Assets and spokes linked by `underlying` address. Tokenization flag per spoke entry deploys ERC4626 vault. Adapted from V3 Config Engine pattern.

### External Libraries

`LiquidationLogic` (`src/spoke/libraries/LiquidationLogic.sol`) is an **external library** (functions are `external`/`public`, not `internal`). It requires separate deployment and bytecode linking. The compiled SpokeInstance artifact has placeholder bytes `__$a48140799943db40fec4e369e92a011fa5$__` at 3 offsets that must be replaced with the deployed library address.

## Code Conventions

- License: `// SPDX-License-Identifier: UNLICENSED` + `// Copyright (c) 2025 Aave Labs`
- Imports: curly brace style `import {X} from 'src/path/X.sol';`
- Formatting: Prettier with `printWidth: 100`, `tabWidth: 2`, `singleQuote: true`, `bracketSpacing: false`
- Private/internal vars: `_camelCase` underscore prefix
- Test files: `.t.sol` extension, inherit from `Base.t.sol` for full environment
- Test roles: use `vm.prank(ROLE_HOLDER)` pattern to call restricted functions

## Code Freeze Rules

- `src/hub/`, `src/spoke/` — **FROZEN** protocol contracts, do not modify
- `src/deployments/` — can be modified
- `tests/` — always modifiable

## Test Infrastructure

`tests/Base.t.sol` (~2800 lines) provides the full test environment: deploys all contracts, sets up roles, creates test tokens/users. Key helpers:

- `_setupFixturesRoles()` — grants all roles via AccessManager
- `_mockSupplySharePrice()` — mock hub state (hub must be initialized first)
- `_mockReservePriceHelper()` — mock oracle prices
- Deployment tests use separate base: `tests/deployments/batches/BatchBase.t.sol`

## Dependencies

All dependencies are vendored in `src/dependencies/` (OpenZeppelin, Chainlink, Solady) rather than managed via package managers. Only `forge-std` and `erc4626-tests` are in `lib/`.
