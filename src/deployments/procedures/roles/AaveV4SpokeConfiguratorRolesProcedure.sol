// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

library AaveV4SpokeConfiguratorRolesProcedure {
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorAdminRole(accessManager, admin);
    grantSpokeFreezeRole(accessManager, admin);
    grantSpokePauseRole(accessManager, admin);
  }

  function grantSpokeConfiguratorAdminRole(address accessManager, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantSpokeFreezeRole(address accessManager, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({
      roleId: Roles.SPOKE_FREEZE_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantSpokePauseRole(address accessManager, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
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
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spokeConfigurator);
    bytes4[] memory selectors = getSpokeConfiguratorAdminRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE
    );
  }

  function setupSpokeFreezeRole(address accessManager, address spokeConfigurator) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spokeConfigurator);
    bytes4[] memory selectors = getSpokeFreezeRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_FREEZE_ROLE
    );
  }

  function setupSpokePauseRole(address accessManager, address spokeConfigurator) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spokeConfigurator);
    bytes4[] memory selectors = getSpokePauseRoleSelectors();
    IAccessManager(accessManager).setTargetFunctionRole(
      spokeConfigurator,
      selectors,
      Roles.SPOKE_PAUSE_ROLE
    );
  }

  function getSpokeConfiguratorAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](18);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
    selectors[5] = ISpokeConfigurator.addReserve.selector;
    selectors[6] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[7] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[8] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[9] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[10] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[11] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[12] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[13] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[14] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[15] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[16] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[17] = ISpokeConfigurator.updatePositionManager.selector;
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
}
