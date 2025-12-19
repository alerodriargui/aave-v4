// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract PositionConfigPositionManagerTest is SpokeBase {
  using ConfigPermissionsMap for ConfigPermissions;

  ISpoke public spoke;
  PositionConfigPositionManager public positionManager;
  TestReturnValues public returnValues;

  ConfigPermissions emptyPermissions;

  function setUp() public virtual override {
    super.setUp();

    spoke = spoke1;
    positionManager = new PositionConfigPositionManager(address(spoke));

    emptyPermissions = ConfigPermissions.wrap(0);

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke.setUserPositionManager(address(positionManager), true);
  }

  function test_setGlobalPermission() public {
    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions = emptyPermissions
      .setCanSetUsingAsCollateral(true)
      .setCanUpdateUserRiskPremium(true)
      .setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, true);

    permissions = positionManager.getConfigPermissions(bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_fuzz(bool status) public {
    if (status) {
      ConfigPermissions newPermissions = emptyPermissions
        .setCanSetUsingAsCollateral(status)
        .setCanUpdateUserRiskPremium(status)
        .setCanUpdateUserDynamicConfig(status);
      vm.expectEmit(address(positionManager));
      emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    }
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, status);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(bob, alice);
    assertEq(permissions.canSetUsingAsCollateral, status);
    assertEq(permissions.canUpdateUserRiskPremium, status);
    assertEq(permissions.canUpdateUserDynamicConfig, status);
  }

  function test_setGlobalPermission_removeAllPermissions() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, true);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, false);

    permissions = positionManager.getConfigPermissions(bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_removePreviousPermissions() public {
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(bob, true);
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(bob, true);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, false);

    permissions = positionManager.getConfigPermissions(bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setUsingAsCollateralPermission() public {
    assertFalse(positionManager.getConfigPermissions(bob, alice).canSetUsingAsCollateral);

    ConfigPermissions newPermissions = emptyPermissions.setCanSetUsingAsCollateral(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(bob, true);

    assertTrue(positionManager.getConfigPermissions(bob, alice).canSetUsingAsCollateral);
  }

  function test_setUsingAsCollateralPermission_remove() public {
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(bob, true);
    assertTrue(positionManager.getConfigPermissions(bob, alice).canSetUsingAsCollateral);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(bob, false);

    assertFalse(positionManager.getConfigPermissions(bob, alice).canSetUsingAsCollateral);
  }

  function test_setUserRiskPremiumPermission() public {
    assertFalse(positionManager.getConfigPermissions(bob, alice).canUpdateUserRiskPremium);

    ConfigPermissions newPermissions = emptyPermissions.setCanUpdateUserRiskPremium(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(bob, true);

    assertTrue(positionManager.getConfigPermissions(bob, alice).canUpdateUserRiskPremium);
  }

  function test_setUserRiskPremiumPermission_remove() public {
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(bob, true);
    assertTrue(positionManager.getConfigPermissions(bob, alice).canUpdateUserRiskPremium);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(bob, false);

    assertFalse(positionManager.getConfigPermissions(bob, alice).canUpdateUserRiskPremium);
  }

  function test_setUserDynamicConfigPermission() public {
    assertFalse(positionManager.getConfigPermissions(bob, alice).canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions = emptyPermissions.setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(bob, true);

    assertTrue(positionManager.getConfigPermissions(bob, alice).canUpdateUserDynamicConfig);
  }

  function test_setUserDynamicConfigPermission_remove() public {
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(bob, true);
    assertTrue(positionManager.getConfigPermissions(bob, alice).canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(bob, false);

    assertFalse(positionManager.getConfigPermissions(bob, alice).canUpdateUserDynamicConfig);
  }

  function test_renounceGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, true);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(bob);
    positionManager.renounceGlobalPermission(alice);

    permissions = positionManager.getConfigPermissions(bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_renounceUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(bob, true);

    assertTrue(positionManager.getConfigPermissions(bob, alice).canSetUsingAsCollateral);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(bob);
    positionManager.renounceUsingAsCollateralPermission(alice);

    assertFalse(positionManager.getConfigPermissions(bob, alice).canSetUsingAsCollateral);
  }

  function test_renounceUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(bob, true);

    assertTrue(positionManager.getConfigPermissions(bob, alice).canUpdateUserRiskPremium);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(bob);
    positionManager.renounceUserRiskPremiumPermission(alice);

    assertFalse(positionManager.getConfigPermissions(bob, alice).canUpdateUserRiskPremium);
  }

  function test_renounceUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(bob, true);

    assertTrue(positionManager.getConfigPermissions(bob, alice).canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(alice, bob, newPermissions);
    vm.prank(bob);
    positionManager.renounceUserDynamicConfigPermission(alice);

    assertFalse(positionManager.getConfigPermissions(bob, alice).canUpdateUserDynamicConfig);
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withPermission(
    uint256 reserveId,
    bool useAsCollateral
  ) public {
    reserveId = bound(reserveId, 1, spoke1.getReserveCount() - 1);

    vm.prank(alice);
    positionManager.setUsingAsCollateralPermission(bob, true);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, !useAsCollateral, alice);

    (bool isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, !useAsCollateral);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, address(positionManager), alice, useAsCollateral);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(reserveId, useAsCollateral, alice);

    (isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, useAsCollateral);
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withGlobalPermission(
    uint256 reserveId,
    bool useAsCollateral
  ) public {
    reserveId = bound(reserveId, 1, spoke1.getReserveCount() - 1);

    vm.prank(alice);
    positionManager.setGlobalPermission(bob, true);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, !useAsCollateral, alice);

    (bool isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, !useAsCollateral);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, address(positionManager), alice, useAsCollateral);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(reserveId, useAsCollateral, alice);

    (isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, useAsCollateral);
  }

  function test_setUsingAsCollateralOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IPositionConfigPositionManager.CallerNotAllowed.selector);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(_daiReserveId(spoke1), true, alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_withPermission() public {
    vm.prank(alice);
    positionManager.setUserRiskPremiumPermission(bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IPositionConfigPositionManager.CallerNotAllowed.selector);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_withPermission() public {
    vm.prank(alice);
    positionManager.setUserDynamicConfigPermission(bob, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(bob, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IPositionConfigPositionManager.CallerNotAllowed.selector);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(alice);
  }
}
