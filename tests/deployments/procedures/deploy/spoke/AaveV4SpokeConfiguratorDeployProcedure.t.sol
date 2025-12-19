// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeConfiguratorDeployProcedureTest is ProceduresBase {
  AaveV4SpokeConfiguratorDeployProcedureWrapper
    public aaveV4SpokeConfiguratorDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4SpokeConfiguratorDeployProcedureWrapper = new AaveV4SpokeConfiguratorDeployProcedureWrapper();
  }

  function test_deploySpokeConfigurator() public {
    address spokeConfigurator = aaveV4SpokeConfiguratorDeployProcedureWrapper
      .deploySpokeConfigurator(owner);
    assertNotEq(spokeConfigurator, address(0));
    assertEq(Ownable(spokeConfigurator).owner(), owner);
  }

  function test_deploySpokeConfigurator_reverts() public {
    vm.expectRevert('invalid owner');
    aaveV4SpokeConfiguratorDeployProcedureWrapper.deploySpokeConfigurator(address(0));
  }
}
