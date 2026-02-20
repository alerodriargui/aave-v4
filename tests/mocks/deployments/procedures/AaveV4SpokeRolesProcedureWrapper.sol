// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4SpokeRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantSpokeAdminRole(address accessManager, address admin) external {
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole(accessManager, admin);
  }

  function grantSpokeRole(address accessManager, uint64 role, address admin) external {
    AaveV4SpokeRolesProcedure.grantSpokeRole(accessManager, role, admin);
  }

  function setupSpokeRoles(address accessManager, address spoke) external {
    AaveV4SpokeRolesProcedure.setupSpokeRoles(accessManager, spoke);
  }

  function setupSpokePositionUpdaterRole(address accessManager, address spoke) external {
    AaveV4SpokeRolesProcedure.setupSpokePositionUpdaterRole(accessManager, spoke);
  }

  function setupSpokeConfiguratorRole(address accessManager, address spoke) external {
    AaveV4SpokeRolesProcedure.setupSpokeConfiguratorRole(accessManager, spoke);
  }

  function getSpokePositionUpdaterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getSpokePositionUpdaterRoleSelectors();
  }

  function getSpokeConfiguratorRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getSpokeConfiguratorRoleSelectors();
  }
}
