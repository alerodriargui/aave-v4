// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';
library AaveV4HubConfiguratorRolesProcedure {
  /// @notice Grants all HubConfigurator granular roles to `admin`:
  ///   - HUB_CONFIGURATOR_ADMIN_ROLE
  ///   - HUB_CONFIGURATOR_ASSET_LISTER_ROLE
  ///   - HUB_CONFIGURATOR_SPOKE_ADDER_ROLE
  ///   - HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE
  ///   - HUB_CONFIGURATOR_HALT_ROLE
  ///   - HUB_CONFIGURATOR_DEACTIVATE_ROLE
  ///   - HUB_CONFIGURATOR_CAPS_UDPATER_ROLE
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_ADMIN_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE, admin);
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_HALT_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_DEACTIVATE_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

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
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      Roles.getHubConfiguratorAssetListerRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      Roles.getHubConfiguratorSpokeAdderRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      Roles.getHubConfiguratorInterestRateUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_HALT_ROLE,
      Roles.getHubConfiguratorHalterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_DEACTIVATE_ROLE,
      Roles.getHubConfiguratorActivaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE,
      Roles.getHubConfiguratorCapSetterRoleSelectors()
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
