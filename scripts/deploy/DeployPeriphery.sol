// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {HubConfigurator} from 'src/hub/HubConfigurator.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {ConfigReader} from '../ConfigReader.sol';
import {DeployLogger} from '../DeployLogger.sol';
import {ScriptUtils} from '../ScriptUtils.sol';
import {DeployReport, DeployReportLib, HubReport, SpokeReport} from './DeployTypes.sol';

/// @title DeployPeriphery
/// @notice Handles roles, reserves, gateways, and configurator deployment.
library DeployPeriphery {
  using ConfigReader for string;
  using DeployReportLib for DeployReport;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // ==================== Public Functions ====================

  /// @notice Set AccessManager role mappings for all hubs and spokes.
  function setUpRoles(DeployReport storage report, string memory /* json */) internal {
    AccessManager am = AccessManager(report.accessManager);
    am.grantRole(Roles.HUB_ADMIN_ROLE, report.admin, 0);
    am.grantRole(Roles.SPOKE_ADMIN_ROLE, report.admin, 0);

    // Spoke selectors → SPOKE_ADMIN_ROLE + USER_POSITION_UPDATER_ROLE
    for (uint256 i; i < report.spokes.length; ++i) {
      address spokeAddr = report.spokes[i].spoke;

      {
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = ISpoke.updateLiquidationConfig.selector;
        selectors[1] = ISpoke.addReserve.selector;
        selectors[2] = ISpoke.updateReserveConfig.selector;
        selectors[3] = ISpoke.updateDynamicReserveConfig.selector;
        selectors[4] = ISpoke.addDynamicReserveConfig.selector;
        selectors[5] = ISpoke.updatePositionManager.selector;
        selectors[6] = ISpoke.updateReservePriceSource.selector;
        am.setTargetFunctionRole(spokeAddr, selectors, Roles.SPOKE_ADMIN_ROLE);
      }

      {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ISpoke.updateUserDynamicConfig.selector;
        selectors[1] = ISpoke.updateUserRiskPremium.selector;
        am.setTargetFunctionRole(spokeAddr, selectors, Roles.USER_POSITION_UPDATER_ROLE);
      }
    }

    // Hub selectors → HUB_ADMIN_ROLE + DEFICIT_ELIMINATOR_ROLE
    for (uint256 i; i < report.hubs.length; ++i) {
      address hubAddr = report.hubs[i].hub;

      {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = IHub.addAsset.selector;
        selectors[1] = IHub.updateAssetConfig.selector;
        selectors[2] = IHub.addSpoke.selector;
        selectors[3] = IHub.updateSpokeConfig.selector;
        selectors[4] = IHub.setInterestRateData.selector;
        selectors[5] = IHub.mintFeeShares.selector;
        am.setTargetFunctionRole(hubAddr, selectors, Roles.HUB_ADMIN_ROLE);
      }

      {
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = IHub.eliminateDeficit.selector;
        am.setTargetFunctionRole(hubAddr, selectors, Roles.DEFICIT_ELIMINATOR_ROLE);
      }
    }
  }

  /// @notice Add reserves on spokes, apply liquidation configs.
  function setUpReserves(DeployReport storage report, string memory json) internal {
    DeployLogger.logSection('Reserve Listing');
    for (uint256 ri = 0; json.reserveExists(ri); ri++) {
      _processReserve(report, json.readReserve(ri));
    }

    // Apply liquidation configs to spokes
    for (uint256 i; i < report.spokes.length; ++i) {
      ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(i);
      ISpoke(report.spokes[i].spoke).updateLiquidationConfig(lc);
      DeployLogger.logLiquidationConfig(report.spokes[i].key, lc);
    }
  }

  /// @notice Deploy HubConfigurator + SpokeConfigurator with full role setup.
  function deployConfigurators(DeployReport storage report) internal {
    AccessManager am = AccessManager(report.accessManager);

    report.hubConfigurator = address(new HubConfigurator(report.accessManager));
    report.spokeConfigurator = address(new SpokeConfigurator(report.accessManager));
    DeployLogger.logConfigurator('hubConfigurator', report.hubConfigurator);
    DeployLogger.logConfigurator('spokeConfigurator', report.spokeConfigurator);

    // Level 1: Grant admin roles to configurators so they can call Hub/Spoke
    am.grantRole(Roles.HUB_ADMIN_ROLE, report.hubConfigurator, 0);
    am.grantRole(Roles.SPOKE_ADMIN_ROLE, report.spokeConfigurator, 0);

    // Level 2: Map HubConfigurator functions to HUB_CONFIGURATOR_ROLE (22 selectors)
    {
      bytes4[] memory selectors = new bytes4[](22);
      selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
      selectors[1] = IHubConfigurator.updateFeeReceiver.selector;
      selectors[2] = IHubConfigurator.updateFeeConfig.selector;
      selectors[3] = IHubConfigurator.updateInterestRateStrategy.selector;
      selectors[4] = IHubConfigurator.updateReinvestmentController.selector;
      selectors[5] = IHubConfigurator.resetAssetCaps.selector;
      selectors[6] = IHubConfigurator.deactivateAsset.selector;
      selectors[7] = IHubConfigurator.haltAsset.selector;
      selectors[8] = IHubConfigurator.addSpoke.selector;
      selectors[9] = IHubConfigurator.addSpokeToAssets.selector;
      selectors[10] = IHubConfigurator.updateSpokeActive.selector;
      selectors[11] = IHubConfigurator.updateSpokeHalted.selector;
      selectors[12] = IHubConfigurator.updateSpokeSupplyCap.selector;
      selectors[13] = IHubConfigurator.updateSpokeDrawCap.selector;
      selectors[14] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
      selectors[15] = IHubConfigurator.updateSpokeCaps.selector;
      selectors[16] = IHubConfigurator.deactivateSpoke.selector;
      selectors[17] = IHubConfigurator.haltSpoke.selector;
      selectors[18] = IHubConfigurator.resetSpokeCaps.selector;
      selectors[19] = IHubConfigurator.updateInterestRateData.selector;
      selectors[20] = IHubConfigurator.addAsset.selector;
      selectors[21] = IHubConfigurator.addAssetWithDecimals.selector;
      am.setTargetFunctionRole(report.hubConfigurator, selectors, Roles.HUB_CONFIGURATOR_ROLE);
    }

    // Level 2: Map SpokeConfigurator functions to SPOKE_CONFIGURATOR_ROLE (25 selectors)
    {
      bytes4[] memory selectors = new bytes4[](25);
      selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
      selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
      selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
      selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
      selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
      selectors[5] = ISpokeConfigurator.updateMaxReserves.selector;
      selectors[6] = ISpokeConfigurator.addReserve.selector;
      selectors[7] = ISpokeConfigurator.updatePaused.selector;
      selectors[8] = ISpokeConfigurator.updateFrozen.selector;
      selectors[9] = ISpokeConfigurator.updateBorrowable.selector;
      selectors[10] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
      selectors[11] = ISpokeConfigurator.updateCollateralRisk.selector;
      selectors[12] = ISpokeConfigurator.addCollateralFactor.selector;
      selectors[13] = ISpokeConfigurator.updateCollateralFactor.selector;
      selectors[14] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
      selectors[15] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
      selectors[16] = ISpokeConfigurator.addLiquidationFee.selector;
      selectors[17] = ISpokeConfigurator.updateLiquidationFee.selector;
      selectors[18] = ISpokeConfigurator.addDynamicReserveConfig.selector;
      selectors[19] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
      selectors[20] = ISpokeConfigurator.pauseAllReserves.selector;
      selectors[21] = ISpokeConfigurator.freezeAllReserves.selector;
      selectors[22] = ISpokeConfigurator.pauseReserve.selector;
      selectors[23] = ISpokeConfigurator.freezeReserve.selector;
      selectors[24] = ISpokeConfigurator.updatePositionManager.selector;
      am.setTargetFunctionRole(report.spokeConfigurator, selectors, Roles.SPOKE_CONFIGURATOR_ROLE);
    }

    // Verify all hubs and spokes use the same AccessManager
    for (uint256 i; i < report.hubs.length; ++i) {
      require(
        IHub(report.hubs[i].hub).authority() == report.accessManager,
        'hub authority mismatch'
      );
    }
    for (uint256 i; i < report.spokes.length; ++i) {
      require(
        ISpoke(report.spokes[i].spoke).authority() == report.accessManager,
        'spoke authority mismatch'
      );
    }
  }

  // ==================== Private: Reserve Processing ====================

  function _processReserve(
    DeployReport storage report,
    ConfigReader.ReserveConfig memory conf
  ) private {
    IHub hub = report.hubAddress(conf.hubKey);
    ISpoke spoke = ISpoke(report.findSpoke(conf.spokeKey).spoke);
    address token = report.findToken(conf.assetKey).token;
    address priceFeed = report.findToken(conf.assetKey).priceFeed;
    uint256 aid = ScriptUtils.assetId(hub, token);

    ISpoke.ReserveConfig memory st = ISpoke.ReserveConfig({
      receiveSharesEnabled: conf.receiveSharesEnabled,
      frozen: conf.frozen,
      paused: conf.paused,
      borrowable: conf.borrowable,
      collateralRisk: conf.collateralRisk
    });
    ISpoke.DynamicReserveConfig memory dyn = ISpoke.DynamicReserveConfig({
      collateralFactor: conf.collateralFactor,
      maxLiquidationBonus: conf.maxLiquidationBonus,
      liquidationFee: conf.liquidationFee
    });
    require(priceFeed != address(0), 'price feed unset');
    uint256 reserveId = spoke.addReserve(address(hub), aid, priceFeed, st, dyn);

    require(
      keccak256(abi.encode(spoke.getReserveConfig(reserveId))) == keccak256(abi.encode(st)),
      'ReserveConfig mismatch'
    );
    require(
      keccak256(
        abi.encode(
          spoke.getDynamicReserveConfig(reserveId, spoke.getReserve(reserveId).dynamicConfigKey)
        )
      ) == keccak256(abi.encode(dyn)),
      'DynamicReserveConfig mismatch'
    );

    DeployLogger.logReserveListed(
      conf,
      reserveId,
      aid,
      st,
      dyn,
      IAaveOracle(spoke.ORACLE()).getReserveSource(reserveId),
      IAaveOracle(spoke.ORACLE()).getReservePrice(reserveId)
    );
  }
}
