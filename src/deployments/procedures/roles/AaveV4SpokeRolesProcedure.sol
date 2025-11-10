// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library AaveV4SpokeRolesProcedure {
  function setSpokeRoles(address accessManagerAddress, address spokeAddress) internal {
    bytes4[] memory selectors = new bytes4[](7);
    selectors[0] = ISpoke.updateLiquidationConfig.selector;
    selectors[1] = ISpoke.addReserve.selector;
    selectors[2] = ISpoke.updateReserveConfig.selector;
    selectors[3] = ISpoke.updateReservePriceSource.selector;
    selectors[4] = ISpoke.addDynamicReserveConfig.selector;
    selectors[5] = ISpoke.updateDynamicReserveConfig.selector;
    selectors[6] = ISpoke.updatePositionManager.selector;
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      spokeAddress,
      selectors,
      Roles.SPOKE_ADMIN_ROLE
    );
  }
}
