// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

library AaveV4AccessManagerRolesProcedure {
  function grantRootAdminRole(
    address accessManager,
    address adminToAdd,
    address adminToRemove
  ) internal {
    assert(adminToAdd != address(0));
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
