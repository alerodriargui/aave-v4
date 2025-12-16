// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubDeployProcedureTest is ProceduresBase {
  AaveV4HubDeployProcedureWrapper public aaveV4HubDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4HubDeployProcedureWrapper = new AaveV4HubDeployProcedureWrapper();
  }

  function test_deployHub() public {
    address hub = aaveV4HubDeployProcedureWrapper.deployHub(accessManager);
    assertNotEq(hub, address(0));
    assertEq(IHub(hub).authority(), accessManager);
  }
}
