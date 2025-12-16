// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';
import {
  AaveV4TreasurySpokeDeployProcedureWrapper
} from 'tests/mocks/deployments/AaveV4TreasurySpokeDeployProcedureWrapper.sol';

contract AaveV4TreasurySpokeDeployProcedureTest is ProceduresBase {
  AaveV4TreasurySpokeDeployProcedureWrapper public aaveV4TreasurySpokeDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4TreasurySpokeDeployProcedureWrapper = new AaveV4TreasurySpokeDeployProcedureWrapper();
  }

  function test_deployTreasurySpoke() public {
    address treasurySpoke = aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpoke(
      owner,
      hub
    );
    assertNotEq(treasurySpoke, address(0));
    assertEq(Ownable(treasurySpoke).owner(), owner);
    assertEq(address(ITreasurySpoke(treasurySpoke).HUB()), hub);
  }
}
