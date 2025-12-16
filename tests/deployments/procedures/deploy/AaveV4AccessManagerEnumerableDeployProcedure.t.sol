// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4AccessManagerEnumerableDeployProcedureTest is ProceduresBase {
  AaveV4AccessManagerEnumerableDeployProcedureWrapper
    public aaveV4AccessManagerEnumerableDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4AccessManagerEnumerableDeployProcedureWrapper = new AaveV4AccessManagerEnumerableDeployProcedureWrapper();
  }

  function test_deployAccessManagerEnumerable() public {
    address accessManagerEnumerable = aaveV4AccessManagerEnumerableDeployProcedureWrapper
      .deployAccessManagerEnumerable(accessManagerAdmin);
    assertNotEq(accessManagerEnumerable, address(0));
    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(accessManagerEnumerable)
      .hasRole(
        uint64(AccessManagerEnumerable(accessManagerEnumerable).ADMIN_ROLE()),
        accessManagerAdmin
      );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }
}
