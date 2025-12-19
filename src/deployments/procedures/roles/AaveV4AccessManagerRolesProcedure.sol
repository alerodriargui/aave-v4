// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

library AaveV4AccessManagerRolesProcedure {
  function replaceDefaultAdminRole(
    address accessManager,
    address adminToAdd,
    address adminToRemove
  ) internal {
    require(accessManager != address(0), 'invalid access manager');
    require(adminToAdd != address(0), 'invalid admin to add');
    require(adminToRemove != address(0), 'invalid admin to remove');
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
