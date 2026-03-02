// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

/// @dev Wrapper to call EngineFlags library functions externally so vm.expectRevert works.
contract EngineFlagsHarness {
  function toBool(uint256 flag) external pure returns (bool) {
    return EngineFlags.toBool(flag);
  }

  function fromBool(bool value) external pure returns (uint256) {
    return EngineFlags.fromBool(value);
  }
}

contract EngineFlagsTest is Test {
  EngineFlagsHarness harness;

  function setUp() public {
    harness = new EngineFlagsHarness();
  }

  function test_toBool_zero_returnsFalse() public view {
    assertFalse(harness.toBool(0));
  }

  function test_toBool_one_returnsTrue() public view {
    assertTrue(harness.toBool(1));
  }

  function test_toBool_revertsOnInvalidValue() public {
    vm.expectRevert(abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, 2));
    harness.toBool(2);
  }

  function test_toBool_revertsOnMax() public {
    vm.expectRevert(
      abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, type(uint256).max)
    );
    harness.toBool(type(uint256).max);
  }

  function testFuzz_toBool_revertsOnInvalid(uint256 value) public {
    vm.assume(value > 1);
    vm.expectRevert(abi.encodeWithSelector(EngineFlags.InvalidBoolValue.selector, value));
    harness.toBool(value);
  }

  function test_fromBool_false_returnsDisabled() public view {
    assertEq(harness.fromBool(false), EngineFlags.DISABLED);
  }

  function test_fromBool_true_returnsEnabled() public view {
    assertEq(harness.fromBool(true), EngineFlags.ENABLED);
  }

  function testFuzz_fromBool(bool value) public view {
    uint256 result = harness.fromBool(value);
    if (value) {
      assertEq(result, EngineFlags.ENABLED);
    } else {
      assertEq(result, EngineFlags.DISABLED);
    }
  }

  function test_roundtrip_toBool_fromBool() public view {
    assertEq(harness.fromBool(harness.toBool(0)), EngineFlags.DISABLED);
    assertEq(harness.fromBool(harness.toBool(1)), EngineFlags.ENABLED);
  }

  function test_constants() public pure {
    assertEq(EngineFlags.KEEP_CURRENT, type(uint256).max);
    assertEq(EngineFlags.KEEP_CURRENT_ADDRESS, address(type(uint160).max));
    assertEq(EngineFlags.ENABLED, 1);
    assertEq(EngineFlags.DISABLED, 0);
  }
}
