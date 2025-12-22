# Enigma Dark – Hub-Focused Fuzzing & Invariant Testing Suite

A simplified handler-based invariant testing suite focused exclusively on the **Hub** component of the Aave v4 protocol. This suite performs deep stateful fuzzing against a single hub with actors simulating spokes, validating critical hub system properties through automated property checking and postcondition verification.

## Overview

The suite tests a simplified hub-centric deployment with:
- **1 Hub** with a single interest rate strategy
- **Multiple Actors** simulating spoke behavior (registered as spokes in the hub)
- **2 Base Assets** (USDC, WETH) to keep the asset surface simple and performant
- **Direct Hub Interactions** through handlers that expose hub functions
- **Hub Configuration Management** through the HubConfigurator handler

All protocol actions are monitored by hooks that snapshot state and verify postconditions after each transaction, enabling detection of invariant violations and edge cases specific to hub operations.

## Architecture

### Core Components

**Setup Layer** (`Setup.t.sol`, `base/`)
- Deploys a single Hub with a deterministic interest rate strategy
- Configures 2 base assets (USDC, WETH) for simplicity and performance
- Initializes multiple actors with spoke permissions registered on the hub
- Simplified configuration compared to the full multi-hub, multi-spoke suite

**Handler Layer** (`handlers/`)
- `HubHandler` – hub liquidity operations (supply, draw, repay) through actor-spokes
- `HubConfiguratorHandler` – admin operations (spoke cap updates, risk parameter changes)
- Handlers expose hub interface to actors registered as spokes

**Verification Layer** (`hooks/`, `invariants/`)
- Before/after hooks with state snapshots
- Global and handler-specific postcondition assertions
- Hub invariants (liquidity accounting, share calculations, interest accrual)

**Utilities** (`utils/`)
- Constants and assertion helpers
- Random value generation for fuzzing inputs

## How It Works

1. **Fuzzer** generates random inputs and selects handler functions
2. **Handlers** execute hub operations through actor proxies (respects spoke roles)
3. **Hooks** capture snapshots of relevant hub state variables
4. **Postconditions** validate expected outcomes and state transitions
5. **Invariants** continuously checked across all hub states

## Quick Start

```bash
# Run fuzzing campaign with Medusa
make medusa-hub

# Run with Echidna in assertion mode
make echidna-hub-assert

# Run with Foundry's invariant testing
make foundry-hub-invariants
```

## Key Features

- **Simplified hub-focused testing** for specific hub component validation
- **Actor-based spoke simulation** – no custom spoke deployments, just actors as spokes
- **Comprehensive postcondition checking** after every hub state transition
- **Performance optimized** – minimal asset and spoke count for faster fuzzing
- **Hub-specific invariants** validating liquidity accounting, interest calculations, and spoken cap constraints

---

**Note:** This suite complements the full multi-hub, multi-spoke suite by providing deep, focused testing of hub core functionality in isolation.
