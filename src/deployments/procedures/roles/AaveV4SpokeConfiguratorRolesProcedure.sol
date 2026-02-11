// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

library AaveV4SpokeConfiguratorRolesProcedure {
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorAdminRole(accessManager, admin);
    grantSpokeFreezeRole(accessManager, admin);
    grantSpokePauseRole(accessManager, admin);
  }

  function grantSpokeConfiguratorAdminRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantSpokeFreezeRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_FREEZE_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantSpokePauseRole(address accessManager, address admin) internal {
    _validateAccessManagerAndAdmin(accessManager, admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_PAUSE_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function setupSpokeConfiguratorRoles(address accessManager, address spokeConfigurator) internal {
    setupSpokeConfiguratorAdminRole(accessManager, spokeConfigurator);
    setupSpokeFreezeRole(accessManager, spokeConfigurator);
    setupSpokePauseRole(accessManager, spokeConfigurator);
  }

  function setupSpokeConfiguratorAdminRole(
    address accessManager,
    address spokeConfigurator
  ) internal {
    _validateAccessManagerAndSpokeConfigurator(accessManager, spokeConfigurator);
    bytes4[] memory selectors = getSpokeConfiguratorAdminRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE
    );
  }

  function setupSpokeFreezeRole(address accessManager, address spokeConfigurator) internal {
    _validateAccessManagerAndSpokeConfigurator(accessManager, spokeConfigurator);
    bytes4[] memory selectors = getSpokeFreezeRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_FREEZE_ROLE
    );
  }

  function setupSpokePauseRole(address accessManager, address spokeConfigurator) internal {
    _validateAccessManagerAndSpokeConfigurator(accessManager, spokeConfigurator);
    bytes4[] memory selectors = getSpokePauseRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_PAUSE_ROLE
    );
  }

  function getSpokeConfiguratorAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](19);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
    selectors[5] = ISpokeConfigurator.updateMaxReserves.selector;
    selectors[6] = ISpokeConfigurator.addReserve.selector;
    selectors[7] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[8] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[9] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[10] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[11] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[12] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[13] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[14] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[15] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[16] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[17] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[18] = ISpokeConfigurator.updatePositionManager.selector;
    return selectors;
  }

  function getSpokeFreezeRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = ISpokeConfigurator.updateFrozen.selector;
    selectors[1] = ISpokeConfigurator.freezeAllReserves.selector;
    selectors[2] = ISpokeConfigurator.freezeReserve.selector;
    return selectors;
  }

  function getSpokePauseRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = ISpokeConfigurator.updatePaused.selector;
    selectors[1] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[2] = ISpokeConfigurator.pauseReserve.selector;
    return selectors;
  }

  function _validateAccessManagerAndSpokeConfigurator(
    address accessManager,
    address spokeConfigurator
  ) private pure {
    require(accessManager != address(0), 'invalid access manager');
    require(spokeConfigurator != address(0), 'invalid spoke configurator');
  }

  function _validateAccessManagerAndAdmin(address accessManager, address admin) private pure {
    require(accessManager != address(0), 'invalid access manager');
    require(admin != address(0), 'invalid admin');
  }
}
