// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeRolesProcedureTest is ProceduresBase {
  AaveV4SpokeRolesProcedureWrapper public aaveV4SpokeRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4SpokeRolesProcedureWrapper = new AaveV4SpokeRolesProcedureWrapper();
  }
}
