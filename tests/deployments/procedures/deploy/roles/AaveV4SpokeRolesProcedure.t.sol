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

  function test_grantSpokeAdminRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeAdminRole({accessManager: address(0), admin: admin});

    vm.expectRevert('invalid admin');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeAdminRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantSpokePositionUpdaterRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4SpokeRolesProcedureWrapper.grantSpokePositionUpdaterRole({
      accessManager: address(0),
      admin: admin
    });

    vm.expectRevert('invalid admin');
    aaveV4SpokeRolesProcedureWrapper.grantSpokePositionUpdaterRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantSpokeConfiguratorRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeConfiguratorRole({
      accessManager: address(0),
      admin: admin
    });

    vm.expectRevert('invalid admin');
    aaveV4SpokeRolesProcedureWrapper.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_setupSpokeRoles_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeRoles({accessManager: address(0), spoke: spoke});

    vm.expectRevert('invalid spoke');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeRoles({
      accessManager: accessManager,
      spoke: address(0)
    });
  }

  function test_setupSpokePositionUpdaterRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4SpokeRolesProcedureWrapper.setupSpokePositionUpdaterRole({
      accessManager: address(0),
      spoke: spoke
    });

    vm.expectRevert('invalid spoke');
    aaveV4SpokeRolesProcedureWrapper.setupSpokePositionUpdaterRole({
      accessManager: accessManager,
      spoke: address(0)
    });
  }

  function test_setupSpokeConfiguratorRole_reverts() public {
    vm.expectRevert('invalid access manager');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeConfiguratorRole({
      accessManager: address(0),
      spoke: spoke
    });

    vm.expectRevert('invalid spoke');
    aaveV4SpokeRolesProcedureWrapper.setupSpokeConfiguratorRole({
      accessManager: accessManager,
      spoke: address(0)
    });
  }

  function test_getSpokePositionUpdaterRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokePositionUpdaterRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], ISpoke.updateUserDynamicConfig.selector);
    assertEq(selectors[1], ISpoke.updateUserRiskPremium.selector);
  }

  function test_getSpokeConfiguratorRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4SpokeRolesProcedureWrapper
      .getSpokeConfiguratorRoleSelectors();
    assertEq(selectors.length, 7);
    assertEq(selectors[0], ISpoke.updateLiquidationConfig.selector);
    assertEq(selectors[1], ISpoke.addReserve.selector);
    assertEq(selectors[2], ISpoke.updateReserveConfig.selector);
    assertEq(selectors[3], ISpoke.updateDynamicReserveConfig.selector);
    assertEq(selectors[4], ISpoke.addDynamicReserveConfig.selector);
    assertEq(selectors[5], ISpoke.updatePositionManager.selector);
    assertEq(selectors[6], ISpoke.updateReservePriceSource.selector);
  }
}
