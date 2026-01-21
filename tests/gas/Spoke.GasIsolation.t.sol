// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/gas/Spoke.Operations.base.gas.t.sol';

/// @dev Gas isolation tests to measure specific operations
contract SpokeGasIsolation_Tests is SpokeOperationsGasBase {
  string internal constant NAMESPACE_ISOLATION = 'Spoke.GasIsolation';

  function test_compareBorrowGas() public {
    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 1000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);

    // Measure borrow WITHOUT the new logic (second borrow on same reserve)
    spoke.borrow(reserveId.dai, 100e18, alice);
    skip(100);

    // This is a second borrow on the same reserve, so it won't read _spokeConfig or call borrowCount
    spoke.borrow(reserveId.dai, 50e18, alice);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'borrow: same reserve (no config read, no borrowCount)'
    );

    skip(100);

    // This is a first borrow on a new reserve, so it WILL read _spokeConfig AND call borrowCount
    spoke.borrow(reserveId.weth, 0.01e18, alice);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'borrow: new reserve (WITH config read + borrowCount)'
    );

    vm.stopPrank();
  }

  function test_borrowCountScaling() public {
    // Set up alice with collateral
    vm.startPrank(alice);
    spoke.supply(reserveId.usdx, 10000e6, alice);
    spoke.setUsingAsCollateral(reserveId.usdx, true, alice);
    vm.stopPrank();

    vm.startPrank(bob);
    spoke.supply(reserveId.dai, 10000e18, bob);
    vm.stopPrank();

    // Scenario 1: First borrow (0 existing borrows, borrowCount should be cheaper)
    vm.startPrank(alice);
    spoke.borrow(reserveId.dai, 100e18, alice);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'borrow: first reserve (borrowCount sees 0 existing)'
    );

    skip(100);

    // Scenario 2: Second borrow on different reserve (1 existing borrow)
    spoke.borrow(reserveId.weth, 0.01e18, alice);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'borrow: second reserve (borrowCount sees 1 existing)'
    );

    skip(100);

    // Scenario 3: Third borrow on different reserve (2 existing borrows)
    spoke.borrow(reserveId.wbtc, 0.001e8, alice);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'borrow: third reserve (borrowCount sees 2 existing)'
    );

    vm.stopPrank();
  }

  function test_isolateComponents() public {
    // Deploy a wrapper to test individual components
    GasIsolationWrapper wrapper = new GasIsolationWrapper();

    // Test 1: Just reading a uint16 from storage (simulates _spokeConfig.maxUserBorrows)
    wrapper.readUint16FromStruct();
    vm.snapshotGasLastCall(NAMESPACE_ISOLATION, 'isolated: read uint16 from cold storage struct');

    // Test 2: Warm read
    wrapper.readUint16FromStruct();
    vm.snapshotGasLastCall(NAMESPACE_ISOLATION, 'isolated: read uint16 from warm storage struct');

    // Test 3: borrowCount with 0 borrows
    wrapper.callBorrowCount(1);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'isolated: borrowCount() with 0 borrows, 1 reserveCount'
    );

    // Test 4: borrowCount with 1 borrow
    wrapper.setBorrowing(0, true);
    wrapper.callBorrowCount(1);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'isolated: borrowCount() with 1 borrow, 1 reserveCount'
    );

    // Test 5: borrowCount with higher reserveCount
    wrapper.callBorrowCount(10);
    vm.snapshotGasLastCall(
      NAMESPACE_ISOLATION,
      'isolated: borrowCount() with 1 borrow, 10 reserveCount'
    );

    // Test 6: Combined - read config + call borrowCount (simulates the new code path)
    wrapper.readConfigAndCallBorrowCount(10);
    vm.snapshotGasLastCall(NAMESPACE_ISOLATION, 'isolated: read config + borrowCount() combined');
  }
}

// Wrapper contract to isolate individual operations
contract GasIsolationWrapper {
  using PositionStatusMap for ISpoke.PositionStatus;

  struct TestConfig {
    uint64 field1;
    uint64 field2;
    uint16 field3;
    uint16 field4;
    uint16 targetField; // This simulates maxUserBorrows
  }

  TestConfig public config;
  ISpoke.PositionStatus public positionStatus;

  constructor() {
    config = TestConfig({field1: 1, field2: 2, field3: 3, field4: 4, targetField: 100});
  }

  function readUint16FromStruct() external view returns (uint16) {
    return config.targetField;
  }

  function callBorrowCount(uint256 reserveCount) external view returns (uint256) {
    return positionStatus.borrowCount(reserveCount);
  }

  function setBorrowing(uint256 reserveId, bool borrowing) external {
    positionStatus.setBorrowing(reserveId, borrowing);
  }

  function readConfigAndCallBorrowCount(uint256 reserveCount) external view returns (uint256) {
    uint16 maxUserBorrows = config.targetField;
    uint256 count = positionStatus.borrowCount(reserveCount);
    // Prevent optimization
    if (maxUserBorrows == 0 && count == 0) revert();
    return count;
  }
}
