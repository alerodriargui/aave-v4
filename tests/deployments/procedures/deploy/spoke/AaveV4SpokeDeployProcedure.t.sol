// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4SpokeDeployProcedureTest is ProceduresBase {
  AaveV4SpokeDeployProcedureWrapper public aaveV4SpokeDeployProcedureWrapper;
  function setUp() public override {
    super.setUp();

    aaveV4SpokeDeployProcedureWrapper = new AaveV4SpokeDeployProcedureWrapper();
  }

  function test_deployUpgradableSpokeInstance() public {
    (address spokeProxy, address spokeImplementation) = aaveV4SpokeDeployProcedureWrapper
      .deployUpgradableSpokeInstance(owner, accessManager, aaveOracle);
    assertNotEq(spokeProxy, address(0));
    assertNotEq(spokeImplementation, address(0));
    assertEq(Ownable(ProxyHelper.getProxyAdmin(spokeProxy)).owner(), owner);
    assertEq(ProxyHelper.getImplementation(spokeProxy), spokeImplementation);
    assertEq(ISpoke(spokeProxy).ORACLE(), aaveOracle);
  }
}
