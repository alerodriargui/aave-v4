// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

/// @title AaveV4AccessManagerRolesProcedure Library
/// @author Aave Labs
/// @notice Procedures for labelling protocol roles and managing the default admin role on the AccessManager.
library AaveV4AccessManagerRolesProcedure {
  /// @notice Labels all protocol roles on the AccessManager.
  function labelAllRoles(address accessManagerAddress) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    IAccessManager accessManager = IAccessManager(accessManagerAddress);

    // Hub roles
    accessManager.labelRole(Roles.HUB_DOMAIN_ADMIN_ROLE, 'HUB_DOMAIN_ADMIN_ROLE');
    accessManager.labelRole(Roles.HUB_CONFIGURATOR_ROLE, 'HUB_CONFIGURATOR_ROLE');
    accessManager.labelRole(Roles.HUB_FEE_MINTER_ROLE, 'HUB_FEE_MINTER_ROLE');
    accessManager.labelRole(Roles.HUB_DEFICIT_ELIMINATOR_ROLE, 'HUB_DEFICIT_ELIMINATOR_ROLE');

    // HubConfigurator roles
    accessManager.labelRole(
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      'HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );

    // Spoke roles
    accessManager.labelRole(Roles.SPOKE_DOMAIN_ADMIN_ROLE, 'SPOKE_DOMAIN_ADMIN_ROLE');
    accessManager.labelRole(Roles.SPOKE_CONFIGURATOR_ROLE, 'SPOKE_CONFIGURATOR_ROLE');
    accessManager.labelRole(
      Roles.SPOKE_USER_POSITION_UPDATER_ROLE,
      'SPOKE_USER_POSITION_UPDATER_ROLE'
    );

    // SpokeConfigurator roles
    accessManager.labelRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      'SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE'
    );
  }

  /// @notice The adminToRemove must be the current default admin, otherwise the procedure will revert.
  function replaceDefaultAdminRole(
    address accessManager,
    address adminToAdd,
    address adminToRemove
  ) internal {
    grantAccessManagerAdminRole(accessManager, adminToAdd);
    revokeAccessManagerAdminRole(accessManager, adminToRemove);
  }

  function grantAccessManagerAdminRole(address accessManager, address adminToAdd) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(adminToAdd);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.ACCESS_MANAGER_ADMIN_ROLE,
      account: adminToAdd,
      executionDelay: 0
    });
  }

  function revokeAccessManagerAdminRole(address accessManager, address adminToRemove) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(adminToRemove);
    IAccessManager(accessManager).revokeRole({
      roleId: Roles.ACCESS_MANAGER_ADMIN_ROLE,
      account: adminToRemove
    });
  }
}
