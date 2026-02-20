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

  function test_grantHubRole_reverts() public {
    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubRole({
      accessManager: address(0),
      role: Roles.HUB_FEE_MINTER_ROLE,
      admin: admin
    });

    vm.expectRevert('zero address');
    aaveV4HubRolesProcedureWrapper.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_FEE_MINTER_ROLE,
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

  function test_canCall_hubFeeMinterRole() public {
    _grantAdminToWrapper(address(aaveV4HubRolesProcedureWrapper));
    aaveV4HubRolesProcedureWrapper.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_FEE_MINTER_ROLE,
      admin: admin
    });
    aaveV4HubRolesProcedureWrapper.setupHubFeeMinterRole({accessManager: accessManager, hub: hub});

    bytes4[] memory selectors = aaveV4HubRolesProcedureWrapper.getHubFeeMinterRoleSelectors();
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hub,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(unauthorized, hub, selectors[i]);
      assertFalse(allowed);
    }
  }

  function test_canCall_hubConfiguratorRole() public {
    _grantAdminToWrapper(address(aaveV4HubRolesProcedureWrapper));
    aaveV4HubRolesProcedureWrapper.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: admin
    });
    aaveV4HubRolesProcedureWrapper.setupHubConfiguratorRole({
      accessManager: accessManager,
      hub: hub
    });

    bytes4[] memory selectors = aaveV4HubRolesProcedureWrapper.getHubConfiguratorRoleSelectors();
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hub,
        selectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    address unauthorized = makeAddr('unauthorized');
    for (uint256 i = 0; i < selectors.length; i++) {
      (bool allowed, ) = IAccessManager(accessManager).canCall(unauthorized, hub, selectors[i]);
      assertFalse(allowed);
    }
  }

  function test_canCall_hubAllRoles() public {
    _grantAdminToWrapper(address(aaveV4HubRolesProcedureWrapper));
    aaveV4HubRolesProcedureWrapper.grantHubAdminRole({accessManager: accessManager, admin: admin});
    aaveV4HubRolesProcedureWrapper.setupHubRoles({accessManager: accessManager, hub: hub});

    bytes4[] memory feeMinterSelectors = aaveV4HubRolesProcedureWrapper
      .getHubFeeMinterRoleSelectors();
    for (uint256 i = 0; i < feeMinterSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hub,
        feeMinterSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }

    bytes4[] memory configuratorSelectors = aaveV4HubRolesProcedureWrapper
      .getHubConfiguratorRoleSelectors();
    for (uint256 i = 0; i < configuratorSelectors.length; i++) {
      (bool allowed, uint32 delay) = IAccessManager(accessManager).canCall(
        admin,
        hub,
        configuratorSelectors[i]
      );
      assertTrue(allowed);
      assertEq(delay, 0);
    }
  }
}
