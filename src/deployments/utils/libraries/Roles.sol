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
  // AccessManager roles
  uint64 public constant ACCESS_MANAGER_DEFAULT_ADMIN = 0;
  // Hub roles
  uint64 public constant HUB_CONFIGURATOR_ROLE = 1;
  uint64 public constant HUB_FEE_MINTER_ROLE = 2;
  // Spoke roles
  uint64 public constant SPOKE_USER_POSITION_UPDATER_ROLE = 3;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 4;
  // HubConfigurator roles
  uint64 public constant HUB_CONFIGURATOR_ADMIN_ROLE = 5;
  uint64 public constant HUB_CONFIGURATOR_DEFICIT_ELIMINATOR_ROLE = 6;
  uint64 public constant HUB_CONFIGURATOR_HALT_ROLE = 7;
  uint64 public constant HUB_CONFIGURATOR_DEACTIVATE_ROLE = 8;
  uint64 public constant HUB_CONFIGURATOR_CAPS_UDPATER_ROLE = 9;
  uint64 public constant HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE = 10;
  uint64 public constant HUB_CONFIGURATOR_ASSET_LISTER_ROLE = 11;
  uint64 public constant HUB_CONFIGURATOR_SPOKE_ADDER_ROLE = 12;
  // SpokeConfigurator roles
  uint64 public constant SPOKE_CONFIGURATOR_ADMIN_ROLE = 13;
  uint64 public constant SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE = 14;
  uint64 public constant SPOKE_CONFIGURATOR_FREEZE_ROLE = 15;
  uint64 public constant SPOKE_CONFIGURATOR_PAUSE_ROLE = 16;

  // hub configurator role on Hub
  function getHubConfiguratorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHub.addAsset.selector;
    selectors[1] = IHub.updateAssetConfig.selector;
    selectors[2] = IHub.addSpoke.selector;
    selectors[3] = IHub.updateSpokeConfig.selector;
    selectors[4] = IHub.setInterestRateData.selector;
    return selectors;
  }

  function getHubFeeMinterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.mintFeeShares.selector;
    return selectors;
  }

  function getDeficitEliminatorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.eliminateDeficit.selector;
    return selectors;
  }

  function getHubConfiguratorAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
    selectors[1] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[2] = IHubConfigurator.updateFeeConfig.selector;
    selectors[3] = IHubConfigurator.updateReinvestmentController.selector;
    selectors[4] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    return selectors;
  }

  function getHubConfiguratorAssetListerRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.addAsset.selector;
    selectors[1] = IHubConfigurator.addAssetWithDecimals.selector;
    return selectors;
  }

  function getHubConfiguratorSpokeAdderRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.addSpoke.selector;
    selectors[1] = IHubConfigurator.addSpokeToAssets.selector;
    return selectors;
  }

  function getHubConfiguratorInterestRateUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.updateInterestRateStrategy.selector;
    selectors[1] = IHubConfigurator.updateInterestRateData.selector;
    return selectors;
  }

  function getHubConfiguratorHalterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = IHubConfigurator.haltAsset.selector;
    selectors[1] = IHubConfigurator.haltSpoke.selector;
    selectors[2] = IHubConfigurator.updateSpokeHalted.selector;
    return selectors;
  }

  function getHubConfiguratorActivaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = IHubConfigurator.deactivateAsset.selector;
    selectors[1] = IHubConfigurator.deactivateSpoke.selector;
    selectors[2] = IHubConfigurator.updateSpokeActive.selector;
    return selectors;
  }

  function getHubConfiguratorCapSetterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHubConfigurator.resetAssetCaps.selector;
    selectors[1] = IHubConfigurator.resetSpokeCaps.selector;
    selectors[2] = IHubConfigurator.updateSpokeCaps.selector;
    selectors[3] = IHubConfigurator.updateSpokeSupplyCap.selector;
    selectors[4] = IHubConfigurator.updateSpokeDrawCap.selector;
    return selectors;
  }

  function getSpokePositionUpdaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = ISpoke.updateUserDynamicConfig.selector;
    selectors[1] = ISpoke.updateUserRiskPremium.selector;
    return selectors;
  }

  // spoke configurator role on Spoke
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

  function getSpokeConfiguratorAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](17);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
    selectors[5] = ISpokeConfigurator.updateBorrowable.selector;
    selectors[6] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[7] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[8] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[9] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[10] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[11] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[12] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[13] = ISpokeConfigurator.updateLiquidationFee.selector;
    selectors[14] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[15] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    selectors[16] = ISpokeConfigurator.updatePositionManager.selector;
    return selectors;
  }

  function getSpokeConfiguratorReserveAdderRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpokeConfigurator.addReserve.selector;
    return selectors;
  }

  function getSpokeConfiguratorFreezerRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = ISpokeConfigurator.updateFrozen.selector;
    selectors[1] = ISpokeConfigurator.freezeAllReserves.selector;
    selectors[2] = ISpokeConfigurator.freezeReserve.selector;
    return selectors;
  }

  function getSpokeConfiguratorPauserRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = ISpokeConfigurator.updatePaused.selector;
    selectors[1] = ISpokeConfigurator.pauseAllReserves.selector;
    selectors[2] = ISpokeConfigurator.pauseReserve.selector;
    return selectors;
  }
}
