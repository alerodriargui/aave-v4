// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

library AaveV4HubConfiguratorRolesProcedure {
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorAdminRole(accessManager, admin);
    grantHubHaltRole(accessManager, admin);
    grantHubDeactivateRole(accessManager, admin);
    grantHubCapsResetRole(accessManager, admin);
  }

  function grantHubConfiguratorAdminRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantHubHaltRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.HUB_HALT_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantHubDeactivateRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.HUB_DEACTIVATE_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantHubCapsResetRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.HUB_CAPS_RESET_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function setupHubConfiguratorRoles(address accessManager, address hubConfigurator) internal {
    setupHubConfiguratorAdminRole(accessManager, hubConfigurator);
    setupHubHaltRole(accessManager, hubConfigurator);
    setupHubDeactivateRole(accessManager, hubConfigurator);
    setupHubCapsResetRole(accessManager, hubConfigurator);
  }

  function setupHubConfiguratorAdminRole(address accessManager, address hubConfigurator) internal {
    _validateAccessManagerAndHubConfigurator(accessManager, hubConfigurator);
    bytes4[] memory selectors = getHubConfiguratorAdminRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      hubConfigurator,
      selectors,
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE
    );
  }

  function setupHubHaltRole(address accessManager, address hubConfigurator) internal {
    _validateAccessManagerAndHubConfigurator(accessManager, hubConfigurator);
    bytes4[] memory selectors = getHubHaltRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      hubConfigurator,
      selectors,
      Roles.HUB_HALT_ROLE
    );
  }

  function setupHubDeactivateRole(address accessManager, address hubConfigurator) internal {
    _validateAccessManagerAndHubConfigurator(accessManager, hubConfigurator);
    bytes4[] memory selectors = getHubDeactivateRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      hubConfigurator,
      selectors,
      Roles.HUB_DEACTIVATE_ROLE
    );
  }

  function setupHubCapsResetRole(address accessManager, address hubConfigurator) internal {
    _validateAccessManagerAndHubConfigurator(accessManager, hubConfigurator);
    bytes4[] memory selectors = getHubCapsResetRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      hubConfigurator,
      selectors,
      Roles.HUB_CAPS_RESET_ROLE
    );
  }

  function getHubConfiguratorAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](16);
    selectors[0] = IHubConfigurator.addAsset.selector;
    selectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    selectors[2] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[3] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[4] = IHubConfigurator.updateFeeConfig.selector;
    selectors[5] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[6] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[7] = IHubConfigurator.addSpoke.selector;
    selectors[8] = IHubConfigurator.addSpokeToAssets.selector;
    selectors[9] = IHubConfigurator.updateSpokeActive.selector;
    selectors[10] = IHubConfigurator.updateSpokeHalted.selector;
    selectors[11] = IHubConfigurator.updateSpokeSupplyCap.selector;
    selectors[12] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[13] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    selectors[14] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[15] = IHubConfigurator.updateInterestRateData.selector;
    return selectors;
  }

  function getHubHaltRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.haltAsset.selector;
    selectors[1] = IHubConfigurator.haltSpoke.selector;
    return selectors;
  }

  function getHubDeactivateRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.deactivateAsset.selector;
    selectors[1] = IHubConfigurator.deactivateSpoke.selector;
    return selectors;
  }

  function getHubCapsResetRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.resetAssetCaps.selector;
    selectors[1] = IHubConfigurator.resetSpokeCaps.selector;
    return selectors;
  }

  function _validateAccessManagerAndHubConfigurator(
    address accessManager,
    address hubConfigurator
  ) private pure {
    require(accessManager != address(0), 'invalid access manager');
    require(hubConfigurator != address(0), 'invalid hub configurator');
  }

  function _validateAccessManagerAndAdmin(address accessManager, address admin) private pure {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
  }
}
