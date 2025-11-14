// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

library AaveV4AdminRolesProcedure {
  function setConfiguratorAdminRoles(
    address accessManagerAddress,
    address spokeConfiguratorAddress,
    address hubConfiguratorAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole(Roles.HUB_ADMIN_ROLE, hubConfiguratorAddress, 0);
    IAccessManager(accessManagerAddress).grantRole(
      Roles.SPOKE_ADMIN_ROLE,
      spokeConfiguratorAddress,
      0
    );
  }

  function setConfiguratorHubAdminRole(
    address accessManagerAddress,
    address hubConfiguratorAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole(Roles.HUB_ADMIN_ROLE, hubConfiguratorAddress, 0);
  }

  function setConfiguratorSpokeAdminRole(
    address accessManagerAddress,
    address spokeConfiguratorAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole(
      Roles.SPOKE_ADMIN_ROLE,
      spokeConfiguratorAddress,
      0
    );
  }

  function setNewAdminRole(
    address accessManagerAddress,
    address newAdminAddress,
    address currentAdminAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole(Roles.DEFAULT_ADMIN_ROLE, newAdminAddress, 0);
    IAccessManager(accessManagerAddress).renounceRole(
      Roles.DEFAULT_ADMIN_ROLE,
      currentAdminAddress
    );
  }
}
