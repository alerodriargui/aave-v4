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
      hub,
      salt
    );
    assertEq(Ownable(treasurySpoke).owner(), owner);
    assertEq(Ownable(ProxyHelper.getProxyAdmin(treasurySpoke)).owner(), owner);
  }

  function test_deployTreasurySpoke_reverts() public {
    vm.expectRevert('invalid owner');
    aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpoke({
      owner: address(0),
      hub: hub,
      salt: salt
    });

    vm.expectRevert('invalid hub');
    aaveV4TreasurySpokeDeployProcedureWrapper.deployTreasurySpoke({
      owner: owner,
      hub: address(0),
      salt: salt
    });
  }
}
