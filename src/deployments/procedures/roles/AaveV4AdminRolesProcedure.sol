// SPDX-License-Identifier: MIT
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
}
