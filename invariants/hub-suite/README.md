# Hub-Focused Fuzzing & Invariant Testing Suite

A handler-based invariant testing suite focused exclusively on the **Hub** component of the Aave v4 protocol. This suite performs deep stateful fuzzing against a single hub with actors simulating spokes, validating critical hub system properties through automated property checking and postcondition verification.

Hub-suite is the **canonical source** for all hub-related specs and invariant assertions. The protocol-suite imports from hub-suite — hub-suite has zero protocol-suite dependencies.

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

**Spec Layer** (`specs/`)

- `HubInvariantsSpec` – canonical hub invariant string constants (INV*HUB*\_, ERC4626\_\_, AVAILABILITY\_\*)
- `HubPostconditionsSpec` – canonical hub postcondition string constants (GPOST*HUB*_, HSPOST*HUB*_)
- Protocol-suite inherits these specs; they are defined here only

**Handler Layer** (`handlers/`)

- `HubHandler` – hub liquidity operations (add, remove, draw, restore, etc.) through actor-spokes
- `HubConfiguratorHandler` – admin operations (spoke cap updates, risk parameter changes)
- `DonationAttackHandler` – simulates direct token transfers to the hub

**Invariant Layer** (`invariants/`)

- `HubInvariantAssertions` – abstract parameterized hub invariant assertion logic (INV_HUB_A through P). Importable by other suites
- `HubInvariants` – concrete invariants extending `HubInvariantAssertions`, adds ERC4626 and AVAILABILITY assertions specific to the hub-suite

**Verification Layer** (`hooks/`)

- Before/after hooks with state snapshots
- Global and handler-specific postcondition assertions

### Reuse by Protocol-Suite

Hub-suite exports reusable abstracts that protocol-suite imports:

```
protocol-suite → hub-suite → shared/
```

| Hub-suite export         | Protocol-suite usage                                   |
| ------------------------ | ------------------------------------------------------ |
| `HubInvariantsSpec`      | Inherited by `InvariantsSpec` for hub string constants |
| `HubPostconditionsSpec`  | Inherited by `PostconditionsSpec` for hub strings      |
| `HubInvariantAssertions` | Inherited by `Invariants.t.sol` for hub assert logic   |

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
```

## Key Features

- **Canonical hub logic** — single source of truth for hub specs and invariant assertions
- **Actor-based spoke simulation** – no custom spoke deployments, just actors as spokes
- **Comprehensive postcondition checking** after every hub state transition
- **Performance optimized** – minimal asset and spoke count for faster fuzzing
- **Reusable invariant abstracts** – `HubInvariantAssertions` importable by any suite

---

**Note:** This suite complements the full multi-hub, multi-spoke protocol-suite by providing deep, focused testing of hub core functionality in isolation.
