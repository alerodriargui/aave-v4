// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4HubRolesProcedure {
  /// @notice Grants all Hub roles to `admin`:
  ///   - HUB_FEE_MINTER_ROLE
  ///   - HUB_CONFIGURATOR_ROLE
  function grantHubAdminRole(address accessManager, address admin) internal {
    grantHubRole(accessManager, Roles.HUB_FEE_MINTER_ROLE, admin);
    grantHubRole(accessManager, Roles.HUB_CONFIGURATOR_ROLE, admin);
  }

  function grantHubRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Maps Hub function selectors to their roles:
  ///   - HubFeeMinterRoleSelectors -> HUB_FEE_MINTER_ROLE
  ///   - HubConfiguratorRoleSelectors -> HUB_CONFIGURATOR_ROLE
  ///   - DeficitEliminatorRoleSelectors -> DEFICIT_ELIMINATOR_ROLE
  function setupHubRoles(address accessManager, address hub) internal {
    setupHubFeeMinterRole(accessManager, hub);
    setupHubConfiguratorRole(accessManager, hub);
    setupDeficitEliminatorRole(accessManager, hub);
  }

  function setupHubFeeMinterRole(address accessManager, address hub) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hub);
    bytes4[] memory selectors = Roles.getHubFeeMinterRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(hub, selectors, Roles.HUB_FEE_MINTER_ROLE);
  }

  function setupHubConfiguratorRole(address accessManager, address hub) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hub);
    bytes4[] memory selectors = Roles.getHubConfiguratorRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      hub,
      selectors,
      Roles.HUB_CONFIGURATOR_ROLE
    );
  }

  function setupDeficitEliminatorRole(address accessManager, address hub) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hub);
    bytes4[] memory selectors = Roles.getDeficitEliminatorRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      hub,
      selectors,
      Roles.DEFICIT_ELIMINATOR_ROLE
    );
  }
}
