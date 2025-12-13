// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library AaveV4SpokeRolesProcedure {
  function grantSpokeConfiguratorRole(address accessManagerAddress, address admin) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.SPOKE_CONFIGURATOR_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantSpokeAdminRole(address accessManagerAddress, address admin) internal {
    grantSpokePositionUpdaterRole(accessManagerAddress, admin);
    grantSpokeConfiguratorRole(accessManagerAddress, admin);
  }

  function grantSpokePositionUpdaterRole(address accessManagerAddress, address admin) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.SPOKE_POSITION_UPDATER_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function setSpokeRoles(address accessManagerAddress, address spokeAddress) internal {
    setSpokePositionUpdaterRole(accessManagerAddress, spokeAddress);
    setSpokeConfiguratorRole(accessManagerAddress, spokeAddress);
  }

  function setSpokePositionUpdaterRole(
    address accessManagerAddress,
    address spokeAddress
  ) internal {
    bytes4[] memory selectors = getSpokePositionUpdaterRoleSelectors();
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      spokeAddress,
      selectors,
      Roles.SPOKE_POSITION_UPDATER_ROLE
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
