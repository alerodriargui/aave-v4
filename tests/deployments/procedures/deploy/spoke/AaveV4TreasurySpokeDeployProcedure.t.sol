// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

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

  function test_deployTreasurySpoke_revertsWithInvalidParam() public {
    vm.expectRevert(
      abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'owner')
    );
    aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpoke({owner: address(0), hub: hub});

    vm.expectRevert(abi.encodeWithSelector(AaveV4DeployProcedureBase.InvalidParam.selector, 'hub'));
    aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpoke({owner: owner, hub: address(0)});
  }
}
