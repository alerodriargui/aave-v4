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
/// Role IDs are namespaced by domain: Hub (1-99), HubConfigurator (100-199),
/// Spoke (200-299), SpokeConfigurator (300-399).
library Roles {
  // AccessManager roles
  uint64 public constant ACCESS_MANAGER_DEFAULT_ADMIN = 0;

  // Hub roles
  uint64 public constant HUB_CONFIGURATOR_ROLE = 1;
  uint64 public constant HUB_FEE_MINTER_ROLE = 2;
  uint64 public constant HUB_DEFICIT_ELIMINATOR_ROLE = 3;

  // HubConfigurator roles
  uint64 public constant HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE = 100;
  uint64 public constant HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE = 101;
  uint64 public constant HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE = 102;
  uint64 public constant HUB_CONFIGURATOR_HALTER_ROLE = 103;
  uint64 public constant HUB_CONFIGURATOR_DEACTIVATOR_ROLE = 104;
  uint64 public constant HUB_CONFIGURATOR_CAPS_RESETTER_ROLE = 105;
  uint64 public constant HUB_CONFIGURATOR_CAPS_UPDATER_ROLE = 106;
  uint64 public constant HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE = 107;
  uint64 public constant HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE = 108;
  uint64 public constant HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE = 109;
  uint64 public constant HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE = 110;
  uint64 public constant HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE = 111;
  uint64 public constant HUB_CONFIGURATOR_ASSET_LISTER_ROLE = 112;
  uint64 public constant HUB_CONFIGURATOR_SPOKE_ADDER_ROLE = 113;

  // Spoke roles
  uint64 public constant SPOKE_USER_POSITION_UPDATER_ROLE = 200;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 201;

  // SpokeConfigurator roles
  uint64 public constant SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE = 301;
  uint64 public constant SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE = 302;
  uint64 public constant SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE = 303;
  uint64 public constant SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE = 304;
  uint64 public constant SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE = 305;
  uint64 public constant SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE = 306;
  uint64 public constant SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE = 307;
  uint64 public constant SPOKE_CONFIGURATOR_FREEZER_ROLE = 308;
  uint64 public constant SPOKE_CONFIGURATOR_PAUSER_ROLE = 309;

  // ─── Hub selector getters ───

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

  function getHubDeficitEliminatorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.eliminateDeficit.selector;
    return selectors;
  }

  // ─── HubConfigurator selector getters ───

  function getHubConfiguratorLiquidityFeeUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
    return selectors;
  }

  function getHubConfiguratorFeeConfiguratorRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.updateFeeReceiver.selector;
    selectors[1] = IHubConfigurator.updateFeeConfig.selector;
    return selectors;
  }

  function getHubConfiguratorReinvestmentUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateReinvestmentController.selector;
    return selectors;
  }

  function getHubConfiguratorHalterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = IHubConfigurator.haltAsset.selector;
    selectors[1] = IHubConfigurator.haltSpoke.selector;
    selectors[2] = IHubConfigurator.updateSpokeHalted.selector;
    return selectors;
  }

  function getHubConfiguratorDeactivatorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = IHubConfigurator.deactivateAsset.selector;
    selectors[1] = IHubConfigurator.deactivateSpoke.selector;
    selectors[2] = IHubConfigurator.updateSpokeActive.selector;
    return selectors;
  }

  function getHubConfiguratorCapsResetterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = IHubConfigurator.resetAssetCaps.selector;
    selectors[1] = IHubConfigurator.resetSpokeCaps.selector;
    return selectors;
  }

  function getHubConfiguratorCapsUpdaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeCaps.selector;
    return selectors;
  }

  function getHubConfiguratorDrawCapUpdaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeDrawCap.selector;
    return selectors;
  }

  function getHubConfiguratorAddCapUpdaterRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeAddCap.selector;
    return selectors;
  }

  function getHubConfiguratorSpokeRiskAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
    return selectors;
  }

  function getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateInterestRateStrategy.selector;
    return selectors;
  }

  function getHubConfiguratorInterestRateDataUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHubConfigurator.updateInterestRateData.selector;
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

  // ─── Spoke selector getters ───

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

  // ─── SpokeConfigurator selector getters ───

  function getSpokeConfiguratorPriceAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
    return selectors;
  }

  function getSpokeConfiguratorReserveAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](3);
    selectors[0] = ISpokeConfigurator.updateCollateralRisk.selector;
    selectors[1] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
    selectors[2] = ISpokeConfigurator.updateBorrowable.selector;
    return selectors;
  }

  function getSpokeConfiguratorDynamicReserveAdminRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = ISpokeConfigurator.addCollateralFactor.selector;
    selectors[1] = ISpokeConfigurator.updateCollateralFactor.selector;
    selectors[2] = ISpokeConfigurator.addDynamicReserveConfig.selector;
    selectors[3] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
    return selectors;
  }

  function getSpokeConfiguratorPositionManagerAdminRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = ISpokeConfigurator.updatePositionManager.selector;
    return selectors;
  }

  function getSpokeConfiguratorLiquidationUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
    selectors[1] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
    selectors[2] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationConfig.selector;
    return selectors;
  }

  function getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors()
    internal
    pure
    returns (bytes4[] memory)
  {
    bytes4[] memory selectors = new bytes4[](4);
    selectors[0] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
    selectors[1] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
    selectors[2] = ISpokeConfigurator.addLiquidationFee.selector;
    selectors[3] = ISpokeConfigurator.updateLiquidationFee.selector;
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
