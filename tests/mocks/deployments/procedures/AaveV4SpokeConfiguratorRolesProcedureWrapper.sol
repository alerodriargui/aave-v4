// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

contract AaveV4SpokeConfiguratorRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) external {
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(accessManager, admin);
  }

  function grantSpokeConfiguratorAdminRole(address accessManager, address admin) external {
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAdminRole(accessManager, admin);
  }

  function grantSpokeFreezeRole(address accessManager, address admin) external {
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeFreezeRole(accessManager, admin);
  }

  function grantSpokePauseRole(address accessManager, address admin) external {
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokePauseRole(accessManager, admin);
  }

  function setupSpokeConfiguratorRoles(address accessManager, address spokeConfigurator) external {
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      accessManager,
      spokeConfigurator
    );
  }

  function setupSpokeConfiguratorAdminRole(
    address accessManager,
    address spokeConfigurator
  ) external {
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAdminRole(
      accessManager,
      spokeConfigurator
    );
  }

  function setupSpokeFreezeRole(address accessManager, address spokeConfigurator) external {
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeFreezeRole(accessManager, spokeConfigurator);
  }

  function setupSpokePauseRole(address accessManager, address spokeConfigurator) external {
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokePauseRole(accessManager, spokeConfigurator);
  }

  function getSpokeConfiguratorAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4SpokeConfiguratorRolesProcedure.getSpokeConfiguratorAdminRoleSelectors();
  }

  function getSpokeFreezeRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4SpokeConfiguratorRolesProcedure.getSpokeFreezeRoleSelectors();
  }

  function getSpokePauseRoleSelectors() external pure returns (bytes4[] memory) {
    return AaveV4SpokeConfiguratorRolesProcedure.getSpokePauseRoleSelectors();
  }
}
