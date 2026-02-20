// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';
library AaveV4HubConfiguratorRolesProcedure {
  /// @notice Grants all HubConfigurator granular roles to `admin`:
  ///   - HUB_CONFIGURATOR_ADMIN_ROLE
  ///   - HUB_HALT_ROLE
  ///   - HUB_DEACTIVATE_ROLE
  ///   - HUB_CAPS_RESET_ROLE
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_ADMIN_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_HALT_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_DEACTIVATE_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CAPS_RESET_ROLE, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Maps HubConfigurator function selectors to their granular roles:
  ///   - HubConfiguratorAdminRoleSelectors -> HUB_CONFIGURATOR_ADMIN_ROLE
  ///   - HubHaltRoleSelectors -> HUB_HALT_ROLE
  ///   - HubDeactivateRoleSelectors -> HUB_DEACTIVATE_ROLE
  ///   - HubCapsResetRoleSelectors -> HUB_CAPS_RESET_ROLE
  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) internal {
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
      Roles.getHubConfiguratorAdminRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_HALT_ROLE,
      Roles.getHubHaltRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_DEACTIVATE_ROLE,
      Roles.getHubDeactivateRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CAPS_RESET_ROLE,
      Roles.getHubCapsResetRoleSelectors()
    );
  }

  function setupHubConfiguratorRole(
    address accessManager,
    address hubConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hubConfigurator);
    IAccessManager(accessManager).setTargetFunctionRole(hubConfigurator, selectors, role);
  }
}
