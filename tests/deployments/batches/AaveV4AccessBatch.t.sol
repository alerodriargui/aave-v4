// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4AccessBatchTest is BatchBaseTest {
  AaveV4AccessBatch public aaveV4AccessBatch;
  function setUp() public override {
    super.setUp();
    aaveV4AccessBatch = new AaveV4AccessBatch(admin);
  }

  function test_getReport() public view {
    BatchReports.AccessBatchReport memory report = aaveV4AccessBatch.getReport();
    assertNotEq(report.accessManager, address(0));

    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(report.accessManager).hasRole(
      Roles.DEFAULT_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }
}
