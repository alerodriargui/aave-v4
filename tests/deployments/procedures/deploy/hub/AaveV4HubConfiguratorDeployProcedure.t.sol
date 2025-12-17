// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubConfiguratorDeployProcedureTest is ProceduresBase {
  AaveV4HubConfiguratorDeployProcedureWrapper public aaveV4HubConfiguratorDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4HubConfiguratorDeployProcedureWrapper = new AaveV4HubConfiguratorDeployProcedureWrapper();
  }

  function test_deployHubConfigurator() public {
    address hubConfigurator = aaveV4HubConfiguratorDeployProcedureWrapper.deployHubConfigurator(
      owner
    );
    assertNotEq(hubConfigurator, address(0));
    assertEq(Ownable(hubConfigurator).owner(), owner);
  }

  function test_deployHubConfigurator_revertsWithInvalidParam() public {
    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'owner')
    );
    aaveV4HubConfiguratorDeployProcedureWrapper.deployHubConfigurator(address(0));
  }
}
