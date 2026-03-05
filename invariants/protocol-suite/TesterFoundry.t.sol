// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// Contracts
import {StdInvariant} from 'forge-std/StdInvariant.sol';
import {Invariants} from './Invariants.t.sol';
import {Setup} from './Setup.t.sol';

/// @title TesterFoundry
/// @notice Entry point for invariant testing, inherits all contracts, invariants & handler
/// @dev Mono contract that contains all the testing logic
contract TesterFoundry is Invariants, Setup, StdInvariant {
  /// forge-config: default.invariant.fail-on-revert = false
  /// forge-config: default.invariant.runs = 1000
  /// forge-config: default.invariant.depth = 100
  /// forge-config: default.invariant.corpus-dir = "invariants/_corpus/foundry"
  /// forge-config: default.invariant.show-solidity = true
  /// forge-config: default.invariant.show-metrics = true
  /// forge-config: default.fuzz.seed = '0x1'
  /// forge-config: default.fuzz.include-storage = true
  /// forge-config: default.fuzz.include-push-bytes = true
  /// forge-config: default.fuzz.call-override = false
  /// forge-config: default.fuzz.dictionary-weight = 80
  /// forge-config: default.fuzz.shrink-sequence = true
  /// @dev Foundry compatibility faster setup debugging
  function setUp() public {
    // Deploy protocol contracts and protocol actors
    _setUp();

    // Set the target contract
    targetContract(address(this));

    // Exclude target selectors
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(keccak256('checkPostConditions()'));

    excludeSelector(FuzzSelector({addr: address(this), selectors: selectors}));

    // Set the target senders
    targetSender(USER1);
    targetSender(USER2);
    targetSender(USER3);
  }
}
