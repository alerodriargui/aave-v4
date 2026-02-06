// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract PositionConfigPositionManagerTest is SpokeBase {
  using ConfigPermissionsMap for ConfigPermissions;

  PositionConfigPositionManager public positionManager;
  TestReturnValues public returnValues;

  ConfigPermissions emptyPermissions;

  function setUp() public virtual override {
    super.setUp();

    positionManager = new PositionConfigPositionManager(address(ADMIN));

    emptyPermissions = ConfigPermissions.wrap(0);

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);

    vm.prank(ADMIN);
    positionManager.registerSpoke(address(spoke1), true);
  }

  function test_setGlobalPermission() public {
    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions = emptyPermissions
      .setCanSetUsingAsCollateral(true)
      .setCanUpdateUserRiskPremium(true)
      .setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
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
      emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
        address(spoke1),
        alice,
        bob,
        newPermissions
      );
    }
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, status);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertEq(permissions.canSetUsingAsCollateral, status);
    assertEq(permissions.canUpdateUserRiskPremium, status);
    assertEq(permissions.canUpdateUserDynamicConfig, status);
  }

  function test_setGlobalPermission_removeAllPermissions() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, false);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_removePreviousPermissions() public {
    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke1), bob, true);
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, false);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_setGlobalPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke2), bob, true);
  }

  function test_setCanUpdateUsingAsCollateralPermission() public {
    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canSetUsingAsCollateral
    );
    ConfigPermissions newPermissions = emptyPermissions.setCanSetUsingAsCollateral(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke1), bob, true);

    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canSetUsingAsCollateral
    );
  }

  function test_setCanUpdateUsingAsCollateralPermission_remove() public {
    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke1), bob, true);
    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canSetUsingAsCollateral
    );

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke1), bob, false);

    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canSetUsingAsCollateral
    );
  }

  function test_setCanUpdateUsingAsCollateralPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke2), bob, true);
  }

  function test_setCanUpdateUserRiskPremiumPermission() public {
    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserRiskPremium
    );
    ConfigPermissions newPermissions = emptyPermissions.setCanUpdateUserRiskPremium(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserRiskPremium
    );
  }

  function test_setCanUpdateUserRiskPremiumPermission_remove() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);
    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserRiskPremium
    );

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, false);

    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserRiskPremium
    );
  }

  function test_setCanUpdateUserRiskPremiumPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke2), bob, true);
  }

  function test_setCanUpdateUserDynamicConfigPermission() public {
    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserDynamicConfig
    );
    ConfigPermissions newPermissions = emptyPermissions.setCanUpdateUserDynamicConfig(true);

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserDynamicConfig
    );
  }

  function test_setCanUpdateUserDynamicConfigPermission_remove() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);
    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserDynamicConfig
    );

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, false);

    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserDynamicConfig
    );
  }

  function test_setCanUpdateUserDynamicConfigPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke2), bob, true);
  }

  function test_renounceGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceGlobalPermission(address(spoke1), alice);

    permissions = positionManager.getConfigPermissions(address(spoke1), bob, alice);
    assertFalse(permissions.canSetUsingAsCollateral);
    assertFalse(permissions.canUpdateUserRiskPremium);
    assertFalse(permissions.canUpdateUserDynamicConfig);
  }

  function test_renounceGlobalPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceGlobalPermission(address(spoke2), alice);
  }

  function test_renounceCanUpdateUsingAsCollateralPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke1), bob, true);

    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canSetUsingAsCollateral
    );

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceCanUpdateUsingAsCollateralPermission(address(spoke1), alice);

    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canSetUsingAsCollateral
    );
  }

  function test_renounceCanUpdateUsingAsCollateralPermission_revertsWith_SpokeNotRegistered()
    public
  {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCanUpdateUsingAsCollateralPermission(address(spoke2), alice);
  }

  function test_renounceCanUpdateUserRiskPremiumPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserRiskPremium
    );

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceCanUpdateUserRiskPremiumPermission(address(spoke1), alice);

    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserRiskPremium
    );
  }

  function test_renounceCanUpdateUserRiskPremiumPermission_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCanUpdateUserRiskPremiumPermission(address(spoke2), alice);
  }

  function test_renounceCanUpdateUserDynamicConfigPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    assertTrue(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserDynamicConfig
    );

    ConfigPermissions newPermissions;

    vm.expectEmit(address(positionManager));
    emit IPositionConfigPositionManager.ConfigPermissionsUpdated(
      address(spoke1),
      alice,
      bob,
      newPermissions
    );
    vm.prank(bob);
    positionManager.renounceCanUpdateUserDynamicConfigPermission(address(spoke1), alice);

    assertFalse(
      positionManager.getConfigPermissions(address(spoke1), bob, alice).canUpdateUserDynamicConfig
    );
  }

  function test_renounceCanUpdateUserDynamicConfigPermission_revertsWith_SpokeNotRegistered()
    public
  {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.renounceCanUpdateUserDynamicConfigPermission(address(spoke2), alice);
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withPermission(
    uint256 reserveId,
    bool useAsCollateral
  ) public {
    reserveId = bound(reserveId, 1, spoke1.getReserveCount() - 1);

    vm.prank(alice);
    positionManager.setCanUpdateUsingAsCollateralPermission(address(spoke1), bob, true);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, !useAsCollateral, alice);

    (bool isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, !useAsCollateral);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, address(positionManager), alice, useAsCollateral);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      reserveId,
      useAsCollateral,
      alice
    );

    (isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, useAsCollateral);
  }

  function test_setUsingAsCollateralOnBehalfOf_fuzz_withGlobalPermission(
    uint256 reserveId,
    bool useAsCollateral
  ) public {
    reserveId = bound(reserveId, 1, spoke1.getReserveCount() - 1);

    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.prank(alice);
    spoke1.setUsingAsCollateral(reserveId, !useAsCollateral, alice);

    (bool isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, !useAsCollateral);

    vm.expectEmit(address(spoke1));
    emit ISpoke.SetUsingAsCollateral(reserveId, address(positionManager), alice, useAsCollateral);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      reserveId,
      useAsCollateral,
      alice
    );

    (isCollateral, ) = spoke1.getUserReserveStatus(reserveId, alice);
    assertEq(isCollateral, useAsCollateral);
  }

  function test_setUsingAsCollateralOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IPositionConfigPositionManager.CallerNotAllowed.selector);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(
      address(spoke1),
      _daiReserveId(spoke1),
      true,
      alice
    );
  }

  function test_setUsingAsCollateralOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.setUsingAsCollateralOnBehalfOf(address(spoke2), 1, true, alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_withPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserRiskPremiumPermission(address(spoke1), bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, 100e18, alice);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, 75e18, alice);

    vm.expectEmit(address(spoke1));
    emit ISpoke.UpdateUserRiskPremium(alice, _calculateExpectedUserRP(spoke1, alice));
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IPositionConfigPositionManager.CallerNotAllowed.selector);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserRiskPremiumOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.updateUserRiskPremiumOnBehalfOf(address(spoke2), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_withPermission() public {
    vm.prank(alice);
    positionManager.setCanUpdateUserDynamicConfigPermission(address(spoke1), bob, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_withGlobalPermission() public {
    vm.prank(alice);
    positionManager.setGlobalPermission(address(spoke1), bob, true);

    vm.expectEmit(address(spoke1));
    emit ISpoke.RefreshAllUserDynamicConfig(alice);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_revertsWith_CallerNotAllowed() public {
    vm.expectRevert(IPositionConfigPositionManager.CallerNotAllowed.selector);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke1), alice);
  }

  function test_updateUserDynamicConfigOnBehalfOf_revertsWith_SpokeNotRegistered() public {
    vm.expectRevert(IPositionManagerBase.SpokeNotRegistered.selector);
    vm.prank(bob);
    positionManager.updateUserDynamicConfigOnBehalfOf(address(spoke2), alice);
  }

  function test_multicall() public {
    bytes[] memory calls = new bytes[](2);
    calls[0] = abi.encodeWithSignature(
      'setGlobalPermission(address,address,bool)',
      address(spoke1),
      bob,
      true
    );
    calls[1] = abi.encodeWithSignature(
      'setGlobalPermission(address,address,bool)',
      address(spoke1),
      carol,
      true
    );

    vm.prank(alice);
    positionManager.multicall(calls);

    IPositionConfigPositionManager.ConfigPermissionValues memory permissions = positionManager
      .getConfigPermissions(address(spoke1), bob, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);

    permissions = positionManager.getConfigPermissions(address(spoke1), carol, alice);
    assertTrue(permissions.canSetUsingAsCollateral);
    assertTrue(permissions.canUpdateUserRiskPremium);
    assertTrue(permissions.canUpdateUserDynamicConfig);
  }
}
