# Enigma Dark – Invariant & Fuzzing Suite

This folder contains a Handler-based invariant testing suite for the Aave v4 protocol. It performs stateful fuzzing (supply/withdraw/borrow/repay, liquidations, config updates) through handler contracts and checks system-level postconditions after every call and for every state.

This suite helps identify invariants violations and protocol misconfigurations via stateful fuzzing.

## Tooling

This suite is compatible with Echidna, Medusa, and Foundry.

## Project Layout

- Setup
  - `Setup.t.sol` – deploys core protocol (Hub, Spokes, Oracle, IR strategy), assets, and actors
  - `base/` – shared storage, hooks plumbing, assertions, and helpers
- Execution
  - `HandlerAggregator.t.sol` – collects handlers used by the fuzzer
  - `handlers/` – user- and admin-facing action drivers (Spoke, TreasurySpoke, Hub/Spoke configurators)
  - `hooks/` – before/after hooks, state snapshots, and postcondition checks
  - `specs/` – property strings
  - `invariants/` – invariant entrypoints (`invariant_*`) and campaign wiring
  - `replays/` – minimal repro tests for failures
- Entrypoint
  - `Tester.t.sol` – top-level test contract that wires the suite together

## Workflow

- The fuzzer calls into handlers with fuzzed inputs.
- Each call is wrapped by hooks that snapshot state and then assert postconditions.
- Handlers use actor proxies to simulate realistic multi-user flows and respect protocol roles.
- Admin handlers exercise configuration updates (reserve config, dynamic reserve config, liquidation settings).

## Running tests

- Echidna:
    - Property mode:
        ```bash
        make echidna
        ```
    - Assertion mode:
        ```bash
        make echidna-assert
        ```
    - Exploration mode:
        ```bash
        make echidna-explore
        ```
    - Generate Replay Tests:
        ```bash
        make runes
        ```
- Medusa:
    - Property & Assertion mode:
        ```bash
        make medusa
        ```
- Foundry Invariants:
    ```bash
    make foundry-invariants
    ```

