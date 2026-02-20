// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4HubConfiguratorRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantHubConfiguratorAllRoles(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(accessManager, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorRole(accessManager, role, admin);
  }

  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles(
      accessManager,
      hubConfigurator
    );
  }

  function setupHubConfiguratorRole(
    address accessManager,
    address hubConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      role,
      selectors
    );
  }

  function getHubConfiguratorAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorAdminRoleSelectors();
  }

  function getHubHaltRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubHaltRoleSelectors();
  }

  function getHubDeactivateRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubDeactivateRoleSelectors();
  }

  function getHubCapsResetRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubCapsResetRoleSelectors();
  }
}
