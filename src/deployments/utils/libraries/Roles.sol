// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title Roles library
/// @author Aave Labs
/// @notice Defines the different roles used by the protocol and their target selectors.
library Roles {
  uint64 public constant DEFAULT_ADMIN_ROLE = 0;
  uint64 public constant HUB_ADMIN_ROLE = 1;
  uint64 public constant SPOKE_ADMIN_ROLE = 2;
  uint64 public constant USER_POSITION_UPDATER_ROLE = 3;
  uint64 public constant HUB_FEE_MINTER_ROLE = 4;
  uint64 public constant HUB_CONFIGURATOR_ROLE = 5;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 6;
  uint64 public constant SPOKE_POSITION_UPDATER_ROLE = 7;
  uint64 public constant DEFICIT_ELIMINATOR_ROLE = 8;
  // HubConfigurator roles
  uint64 public constant HUB_CONFIGURATOR_ADMIN_ROLE = 9;
  uint64 public constant HUB_HALT_ROLE = 10;
  uint64 public constant HUB_DEACTIVATE_ROLE = 11;
  uint64 public constant HUB_CAPS_RESET_ROLE = 12;
  // SpokeConfigurator roles
  uint64 public constant SPOKE_CONFIGURATOR_ADMIN_ROLE = 13;
  uint64 public constant SPOKE_FREEZE_ROLE = 14;
  uint64 public constant SPOKE_PAUSE_ROLE = 15;

  function getHubFeeMinterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.mintFeeShares.selector;
    return selectors;
  }

  function getHubConfiguratorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHub.addAsset.selector;
    selectors[1] = IHub.updateAssetConfig.selector;
    selectors[2] = IHub.addSpoke.selector;
    selectors[3] = IHub.updateSpokeConfig.selector;
    selectors[4] = IHub.setInterestRateData.selector;
    return selectors;
  }

  function getDeficitEliminatorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.eliminateDeficit.selector;
    return selectors;
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

  function getHubConfiguratorAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](16);
    selectors[0] = IHubConfigurator.addAsset.selector;
    selectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    selectors[2] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[3] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[4] = IHubConfigurator.updateFeeConfig.selector;
    selectors[5] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[6] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[7] = IHubConfigurator.addSpoke.selector;
    selectors[8] = IHubConfigurator.addSpokeToAssets.selector;
    selectors[9] = IHubConfigurator.updateSpokeActive.selector;
    selectors[10] = IHubConfigurator.updateSpokeHalted.selector;
    selectors[11] = IHubConfigurator.updateSpokeSupplyCap.selector;
    selectors[12] = IHubConfigurator.updateSpokeDrawCap.selector;
    selectors[13] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    selectors[14] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[15] = IHubConfigurator.updateInterestRateData.selector;
    return selectors;
  }

  function getHubHaltRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.haltAsset.selector;
    selectors[1] = IHubConfigurator.haltSpoke.selector;
    return selectors;
  }

  function getHubDeactivateRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.deactivateAsset.selector;
    selectors[1] = IHubConfigurator.deactivateSpoke.selector;
    return selectors;
  }

  function getHubCapsResetRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.resetAssetCaps.selector;
    selectors[1] = IHubConfigurator.resetSpokeCaps.selector;
    return selectors;
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
