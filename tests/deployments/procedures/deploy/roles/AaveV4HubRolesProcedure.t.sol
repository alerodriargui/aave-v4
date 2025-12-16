// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubRolesProcedureTest is ProceduresBase {
  AaveV4HubRolesProcedureWrapper public aaveV4HubRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4HubRolesProcedureWrapper = new AaveV4HubRolesProcedureWrapper();
  }
}
