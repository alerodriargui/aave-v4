// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

library AaveV4AccessManagerRolesProcedure {
  function grantRootAdminRole(
    address accessManagerAddress,
    address newAdminAddress,
    address currentAdminAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.DEFAULT_ADMIN_ROLE,
      account: newAdminAddress,
      executionDelay: 0
    });
    IAccessManager(accessManagerAddress).renounceRole({
      roleId: Roles.DEFAULT_ADMIN_ROLE,
      callerConfirmation: currentAdminAddress
    });
  }
}
