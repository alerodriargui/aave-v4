// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4HubRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantHubAdminRole(address accessManager, address admin) external {
    AaveV4HubRolesProcedure.grantHubAdminRole(accessManager, admin);
  }

  function grantHubRole(address accessManager, uint64 role, address admin) external {
    AaveV4HubRolesProcedure.grantHubRole(accessManager, role, admin);
  }

  function setupHubRoles(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubRoles(accessManager, hub);
  }

  function setupHubFeeMinterRole(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubFeeMinterRole(accessManager, hub);
  }

  function setupHubConfiguratorRole(address accessManager, address hub) external {
    AaveV4HubRolesProcedure.setupHubConfiguratorRole(accessManager, hub);
  }

  function getHubFeeMinterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubFeeMinterRoleSelectors();
  }

  function getHubConfiguratorRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorRoleSelectors();
  }
}
