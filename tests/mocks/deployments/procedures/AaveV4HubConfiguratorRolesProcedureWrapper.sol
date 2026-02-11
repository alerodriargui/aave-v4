// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';

contract AaveV4HubConfiguratorRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantHubConfiguratorAllRoles(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(accessManager, admin);
  }

  function grantHubConfiguratorAdminRole(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAdminRole(accessManager, admin);
  }

  function grantHubHaltRole(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubHaltRole(accessManager, admin);
  }

  function grantHubDeactivateRole(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubDeactivateRole(accessManager, admin);
  }

  function grantHubCapsResetRole(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubCapsResetRole(accessManager, admin);
  }

  function setupHubConfiguratorRoles(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRoles(accessManager, hubConfigurator);
  }

  function setupHubConfiguratorAdminRole(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAdminRole(
      accessManager,
      hubConfigurator
    );
  }

  function setupHubHaltRole(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubHaltRole(accessManager, hubConfigurator);
  }

  function setupHubDeactivateRole(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubDeactivateRole(accessManager, hubConfigurator);
  }

  function setupHubCapsResetRole(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubCapsResetRole(accessManager, hubConfigurator);
  }

  function getHubConfiguratorAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4HubConfiguratorRolesProcedure.getHubConfiguratorAdminRoleSelectors();
  }

  function getHubHaltRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4HubConfiguratorRolesProcedure.getHubHaltRoleSelectors();
  }

  function getHubDeactivateRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4HubConfiguratorRolesProcedure.getHubDeactivateRoleSelectors();
  }

  function getHubCapsResetRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4HubConfiguratorRolesProcedure.getHubCapsResetRoleSelectors();
  }
}
