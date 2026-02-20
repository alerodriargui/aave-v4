// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';
library AaveV4SpokeConfiguratorRolesProcedure {
  /// @notice Grants all SpokeConfigurator granular roles to `admin`:
  ///   - SPOKE_CONFIGURATOR_ADMIN_ROLE
  ///   - SPOKE_FREEZE_ROLE
  ///   - SPOKE_PAUSE_ROLE
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_FREEZE_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_PAUSE_ROLE, admin);
  }

  function grantSpokeConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Maps SpokeConfigurator function selectors to their granular roles:
  ///   - SpokeConfiguratorAdminRoleSelectors -> SPOKE_CONFIGURATOR_ADMIN_ROLE
  ///   - SpokeFreezeRoleSelectors -> SPOKE_FREEZE_ROLE
  ///   - SpokePauseRoleSelectors -> SPOKE_PAUSE_ROLE
  function setupSpokeConfiguratorRoles(address accessManager, address spokeConfigurator) internal {
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      Roles.getSpokeConfiguratorAdminRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_FREEZE_ROLE,
      Roles.getSpokeFreezeRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_PAUSE_ROLE,
      Roles.getSpokePauseRoleSelectors()
    );
  }

  function setupSpokeConfiguratorRole(
    address accessManager,
    address spokeConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spokeConfigurator);
    IAccessManager(accessManager).setTargetFunctionRole(spokeConfigurator, selectors, role);
  }
}
