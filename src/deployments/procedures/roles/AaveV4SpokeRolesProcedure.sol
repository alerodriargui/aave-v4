// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library AaveV4SpokeRolesProcedure {
  function grantSpokeConfiguratorRole(
    address accessManagerAddress,
    address spokeConfiguratorAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.SPOKE_CONFIGURATOR_ROLE,
      account: spokeConfiguratorAddress,
      executionDelay: 0
    });
  }

  function grantSpokeAdminRole(address accessManagerAddress, address spokeAdminAddress) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.SPOKE_ADMIN_ROLE,
      account: spokeAdminAddress,
      executionDelay: 0
    });
    grantSpokeConfiguratorRole(accessManagerAddress, spokeAdminAddress);
  }

  function setSpokeRoles(address accessManagerAddress, address spokeAddress) internal {
    setSpokeAdminRole(accessManagerAddress, spokeAddress);
    setSpokeConfiguratorRole(accessManagerAddress, spokeAddress);
  }

  function setSpokeAdminRole(address accessManagerAddress, address spokeAddress) internal {
    bytes4[] memory selectors = getSpokeAdminRoleSelectors();
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      spokeAddress,
      selectors,
      Roles.SPOKE_ADMIN_ROLE
    );
  }

  function setSpokeConfiguratorRole(address accessManagerAddress, address spokeAddress) internal {
    bytes4[] memory selectors = getSpokeConfiguratorRoleSelectors();
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      spokeAddress,
      selectors,
      Roles.SPOKE_CONFIGURATOR_ROLE
    );
  }

  function getSpokeAdminRoleSelectors() internal pure returns (bytes4[] memory) {
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
