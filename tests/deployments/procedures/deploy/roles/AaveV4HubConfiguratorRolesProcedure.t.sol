// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

contract AaveV4HubConfiguratorRolesProcedureTest is ProceduresBase {
  AaveV4HubConfiguratorRolesProcedureWrapper public wrapper;
  address public hubConfigurator = makeAddr('hubConfigurator');

  function setUp() public override {
    super.setUp();
    wrapper = new AaveV4HubConfiguratorRolesProcedureWrapper();
  }

  function test_grantHubConfiguratorAdminRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.grantHubConfiguratorAdminRole({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    wrapper.grantHubConfiguratorAdminRole({accessManager: accessManager, admin: address(0)});
  }

  function test_grantHubHaltRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.grantHubHaltRole({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    wrapper.grantHubHaltRole({accessManager: accessManager, admin: address(0)});
  }

  function test_grantHubDeactivateRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.grantHubDeactivateRole({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    wrapper.grantHubDeactivateRole({accessManager: accessManager, admin: address(0)});
  }

  function test_grantHubCapsResetRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.grantHubCapsResetRole({accessManager: address(0), admin: admin});

    vm.expectRevert('zero address');
    wrapper.grantHubCapsResetRole({accessManager: accessManager, admin: address(0)});
  }

  function test_setupHubConfiguratorAllRoles_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: address(0),
      hubConfigurator: hubConfigurator
    });

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: address(0)
    });
  }

  function test_setupHubConfiguratorAdminRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorAdminRole({
      accessManager: address(0),
      hubConfigurator: hubConfigurator
    });

    vm.expectRevert('zero address');
    wrapper.setupHubConfiguratorAdminRole({
      accessManager: accessManager,
      hubConfigurator: address(0)
    });
  }

  function test_setupHubHaltRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupHubHaltRole({accessManager: address(0), hubConfigurator: hubConfigurator});

    vm.expectRevert('zero address');
    wrapper.setupHubHaltRole({accessManager: accessManager, hubConfigurator: address(0)});
  }

  function test_setupHubDeactivateRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupHubDeactivateRole({accessManager: address(0), hubConfigurator: hubConfigurator});

    vm.expectRevert('zero address');
    wrapper.setupHubDeactivateRole({accessManager: accessManager, hubConfigurator: address(0)});
  }

  function test_setupHubCapsResetRole_reverts() public {
    vm.expectRevert('zero address');
    wrapper.setupHubCapsResetRole({accessManager: address(0), hubConfigurator: hubConfigurator});

    vm.expectRevert('zero address');
    wrapper.setupHubCapsResetRole({accessManager: accessManager, hubConfigurator: address(0)});
  }

  function test_grantHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.grantHubConfiguratorAllRoles({accessManager: accessManager, admin: admin});

    (bool hasAdmin, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
      admin
    );
    assertTrue(hasAdmin);

    (bool hasHalt, ) = IAccessManager(accessManager).hasRole(Roles.HUB_HALT_ROLE, admin);
    assertTrue(hasHalt);

    (bool hasDeactivate, ) = IAccessManager(accessManager).hasRole(
      Roles.HUB_DEACTIVATE_ROLE,
      admin
    );
    assertTrue(hasDeactivate);

    (bool hasCapsReset, ) = IAccessManager(accessManager).hasRole(Roles.HUB_CAPS_RESET_ROLE, admin);
    assertTrue(hasCapsReset);
  }

  function test_setupHubConfiguratorAllRoles() public {
    _grantAdminToWrapper(address(wrapper));
    wrapper.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: hubConfigurator
    });

    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.addAsset.selector
      ),
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.haltAsset.selector
      ),
      Roles.HUB_HALT_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.deactivateAsset.selector
      ),
      Roles.HUB_DEACTIVATE_ROLE
    );
    assertEq(
      IAccessManager(accessManager).getTargetFunctionRole(
        hubConfigurator,
        IHubConfigurator.resetAssetCaps.selector
      ),
      Roles.HUB_CAPS_RESET_ROLE
    );
  }

  function _grantAdminToWrapper(address _wrapper) internal {
    vm.prank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(Roles.DEFAULT_ADMIN_ROLE, _wrapper, 0);
  }

  function test_getHubConfiguratorAdminRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubConfiguratorAdminRoleSelectors();
    assertEq(selectors.length, 16);
    assertEq(selectors[0], IHubConfigurator.addAsset.selector);
    assertEq(selectors[1], IHubConfigurator.addAssetWithDecimals.selector);
    assertEq(selectors[2], IHubConfigurator.updateLiquidityFee.selector);
    assertEq(selectors[3], IHubConfigurator.updateFeeReceiver.selector);
    assertEq(selectors[4], IHubConfigurator.updateFeeConfig.selector);
    assertEq(selectors[5], IHubConfigurator.updateInterestRateStrategy.selector);
    assertEq(selectors[6], IHubConfigurator.updateReinvestmentController.selector);
    assertEq(selectors[7], IHubConfigurator.addSpoke.selector);
    assertEq(selectors[8], IHubConfigurator.addSpokeToAssets.selector);
    assertEq(selectors[9], IHubConfigurator.updateSpokeActive.selector);
    assertEq(selectors[10], IHubConfigurator.updateSpokeHalted.selector);
    assertEq(selectors[11], IHubConfigurator.updateSpokeSupplyCap.selector);
    assertEq(selectors[12], IHubConfigurator.updateSpokeDrawCap.selector);
    assertEq(selectors[13], IHubConfigurator.updateSpokeRiskPremiumThreshold.selector);
    assertEq(selectors[14], IHubConfigurator.updateSpokeCaps.selector);
    assertEq(selectors[15], IHubConfigurator.updateInterestRateData.selector);
  }

  function test_getHubHaltRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubHaltRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.haltAsset.selector);
    assertEq(selectors[1], IHubConfigurator.haltSpoke.selector);
  }

  function test_getHubDeactivateRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubDeactivateRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.deactivateAsset.selector);
    assertEq(selectors[1], IHubConfigurator.deactivateSpoke.selector);
  }

  function test_getHubCapsResetRoleSelectors() public view {
    bytes4[] memory selectors = wrapper.getHubCapsResetRoleSelectors();
    assertEq(selectors.length, 2);
    assertEq(selectors[0], IHubConfigurator.resetAssetCaps.selector);
    assertEq(selectors[1], IHubConfigurator.resetSpokeCaps.selector);
  }
}
