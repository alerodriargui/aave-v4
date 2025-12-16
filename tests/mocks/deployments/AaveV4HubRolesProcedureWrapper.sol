// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4HubRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';

contract AaveV4HubRolesProcedureWrapper {
  function grantHubAdminRole(address accessManager, address admin) external {
    AaveV4HubRolesProcedure.grantHubAdminRole(accessManager, admin);
  }

  function grantHubFeeMinterRole(address accessManager, address admin) external {
    AaveV4HubRolesProcedure.grantHubFeeMinterRole(accessManager, admin);
  }

  function grantHubConfiguratorRole(address accessManager, address admin) external {
    AaveV4HubRolesProcedure.grantHubConfiguratorRole(accessManager, admin);
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
    return AaveV4HubRolesProcedure.getHubFeeMinterRoleSelectors();
  }

  function getHubConfiguratorRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4HubRolesProcedure.getHubConfiguratorRoleSelectors();
  }
}
