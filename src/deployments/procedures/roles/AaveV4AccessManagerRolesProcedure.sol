// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4AccessManagerRolesProcedure {
  /// @notice The adminToRemove must be the current default admin, otherwise the procedure will revert.
  function replaceDefaultAdminRole(
    address accessManager,
    address adminToAdd,
    address adminToRemove
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(adminToAdd);
    RolesValidation.validateNonZeroAddress(adminToRemove);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.DEFAULT_ADMIN_ROLE,
      account: adminToAdd,
      executionDelay: 0
    });
    IAccessManager(accessManager).renounceRole({
      roleId: Roles.DEFAULT_ADMIN_ROLE,
      callerConfirmation: adminToRemove
    });
  }
}
