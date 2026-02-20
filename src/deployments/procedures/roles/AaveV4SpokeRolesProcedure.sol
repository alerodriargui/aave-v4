// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4SpokeRolesProcedure {
  /// @notice Grants all Spoke roles to `admin`:
  ///   - SPOKE_POSITION_UPDATER_ROLE
  ///   - SPOKE_CONFIGURATOR_ROLE
  function grantSpokeAdminRole(address accessManager, address admin) internal {
    grantSpokeRole(accessManager, Roles.SPOKE_POSITION_UPDATER_ROLE, admin);
    grantSpokeRole(accessManager, Roles.SPOKE_CONFIGURATOR_ROLE, admin);
  }

  function grantSpokeRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Maps Spoke function selectors to their roles:
  ///   - SpokePositionUpdaterRoleSelectors -> SPOKE_POSITION_UPDATER_ROLE
  ///   - SpokeConfiguratorRoleSelectors -> SPOKE_CONFIGURATOR_ROLE
  function setupSpokeRoles(address accessManager, address spoke) internal {
    setupSpokePositionUpdaterRole(accessManager, spoke);
    setupSpokeConfiguratorRole(accessManager, spoke);
  }

  function setupSpokePositionUpdaterRole(address accessManager, address spoke) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spoke);
    bytes4[] memory selectors = Roles.getSpokePositionUpdaterRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spoke,
      selectors,
      Roles.SPOKE_POSITION_UPDATER_ROLE
    );
  }

  function setupSpokeConfiguratorRole(address accessManager, address spoke) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spoke);
    bytes4[] memory selectors = Roles.getSpokeConfiguratorRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spoke,
      selectors,
      Roles.SPOKE_CONFIGURATOR_ROLE
    );
  }
}
