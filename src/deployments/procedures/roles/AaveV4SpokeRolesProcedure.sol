// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library AaveV4SpokeRolesProcedure {
  function grantSpokeAdminRole(address accessManager, address admin) internal {
    grantSpokePositionUpdaterRole(accessManager, admin);
    grantSpokeConfiguratorRole(accessManager, admin);
  }

  function grantSpokePositionUpdaterRole(address accessManager, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_POSITION_UPDATER_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantSpokeConfiguratorRole(address accessManager, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_CONFIGURATOR_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function setupSpokeRoles(address accessManager, address spoke) internal {
    setupSpokePositionUpdaterRole(accessManager, spoke);
    setupSpokeConfiguratorRole(accessManager, spoke);
  }

  function setupSpokePositionUpdaterRole(address accessManager, address spoke) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spoke);
    bytes4[] memory selectors = getSpokePositionUpdaterRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spoke,
      selectors,
      Roles.SPOKE_POSITION_UPDATER_ROLE
    );
  }

  function setupSpokeConfiguratorRole(address accessManager, address spoke) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spoke);
    bytes4[] memory selectors = getSpokeConfiguratorRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spoke,
      selectors,
      Roles.SPOKE_CONFIGURATOR_ROLE
    );
  }

  function getSpokePositionUpdaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = ISpoke.updateUserDynamicConfig.selector;
    selectors[1] = ISpoke.updateUserRiskPremium.selector;
    return selectors;
  }

  function getSpokeConfiguratorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = ISpoke.updateLiquidationConfig.selector;
    selectors[1] = ISpoke.addReserve.selector;
    selectors[2] = ISpoke.updateReserveConfig.selector;
    selectors[3] = ISpoke.updateDynamicReserveConfig.selector;
    selectors[4] = ISpoke.addDynamicReserveConfig.selector;
    selectors[5] = ISpoke.updatePositionManager.selector;
    selectors[6] = ISpoke.updateReservePriceSource.selector;
    return selectors;
  }
}
