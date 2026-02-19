// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4HubRolesProcedureTest is ProceduresBase {
  AaveV4HubRolesProcedureWrapper public aaveV4HubRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4HubRolesProcedureWrapper = new AaveV4HubRolesProcedureWrapper();
  }

  function test_grantHubAdminRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubAdminRole({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubAdminRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantHubFeeMinterRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubFeeMinterRole({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubFeeMinterRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_grantHubConfiguratorRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubConfiguratorRole({
      accessManager: address(0),
      admin: admin
    });

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubConfiguratorRole({
      accessManager: accessManager,
      admin: address(0)
    });
  }

  function test_setupHubRoles_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.setupHubRoles({accessManager: address(0), hub: hub});

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.setupHubRoles({accessManager: accessManager, hub: address(0)});
  }

  function test_setupHubFeeMinterRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.setupHubFeeMinterRole({accessManager: address(0), hub: hub});

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.setupHubFeeMinterRole({
      accessManager: accessManager,
      hub: address(0)
    });
  }

  function test_setupHubConfiguratorRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.setupHubConfiguratorRole({accessManager: address(0), hub: hub});

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hub: address(0)
    });
  }

  function test_grantHubAdminRole() public {
    _grantAdminToWrapper(address(aaveV4HubRolesProcedureWrapper));
    aaveV4HubRolesProcedureWrapper.grantHubAdminRole({accessManager: accessManager, admin: admin});

    (bool hasFeeMinter, ) = IAccessManager(accessManager).hasRole(Roles.HUB_FEE_MINTER_ROLE, admin);
    assertTrue(hasFeeMinter);

    (bool hasConfigurator, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_ROLE,
      admin
    );
    assertTrue(hasConfigurator);
  }

  function test_setupHubRoles() public {
    _grantAdminToWrapper(address(aaveV4HubRolesProcedureWrapper));
    aaveV4HubRolesProcedureWrapper.setupHubRoles({accessManager: accessManager, hub: hub});

    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(hub, IHub.mintFeeShares.selector),
      Roles.HUB_FEE_MINTER_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(hub, IHub.addAsset.selector),
      Roles.HUB_CONFIGURATOR_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(hub, IHub.eliminateDeficit.selector),
      Roles.DEFICIT_ELIMINATOR_ROLE
    );
  }

  function _grantAdminToWrapper(address wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.DEFAULT_ADMIN_ROLE, wrapper, 0);
  }

  function test_getHubFeeMinterRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4HubRolesProcedureWrapper.getHubFeeMinterRoleSelectors();
    assertEq(selectors.length, 1);
    assertEq(selectors[0], IHub.mintFeeShares.selector);
  }

  function test_getHubConfiguratorRoleSelectors() public view {
    bytes4[] memory selectors = aaveV4HubRolesProcedureWrapper.getHubConfiguratorRoleSelectors();
    assertEq(selectors.length, 5);
    assertEq(selectors[0], IHub.addAsset.selector);
    assertEq(selectors[1], IHub.updateAssetConfig.selector);
    assertEq(selectors[2], IHub.addSpoke.selector);
    assertEq(selectors[3], IHub.updateSpokeConfig.selector);
    assertEq(selectors[4], IHub.setInterestRateData.selector);
  }
}
