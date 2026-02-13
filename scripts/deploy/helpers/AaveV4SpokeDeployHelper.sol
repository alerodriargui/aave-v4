// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'scripts/deploy/helpers/DeployHelpersBase.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title AaveV4SpokeDeployHelper
/// @notice Spoke-side deployment helpers: configure reserves on spokes, set liquidation configs.
///         Can be used standalone (for spoke-only operations) or inherited by a full deploy script.
/// @dev Follows V3 pattern: deployer holds temporary admin roles and calls SpokeConfigurator directly.
///      No config engine is deployed or used during deployment.
abstract contract AaveV4SpokeDeployHelper is DeployHelpersBase {
  using ConfigReader for string;

  /// @notice Configures reserves on all spokes from the JSON config.
  /// @dev Deployer must hold SPOKE_CONFIGURATOR_ADMIN_ROLE (+ FREEZE/PAUSE) to call SpokeConfigurator.
  function _configureReserves(
    string memory json,
    OrchestrationReports.FullDeploymentReport memory report,
    uint256 reserveCount,
    uint256 spokeCount,
    uint256 hubCount
  ) internal {
    address spokeConfigurator_ = report.configuratorBatchReport.spokeConfigurator;

    for (uint256 s; s < spokeCount; s++) {
      string memory sKey = json.spokeKey(s);
      address spokeProxy = report.spokeInstanceBatchReports[s].report.spokeProxy;

      // Find the hub this spoke's reserves reference
      address hub_ = _findHubForSpoke(json, report, sKey, reserveCount, hubCount);
      if (hub_ == address(0)) continue;

      // Set maxReserves from spoke config (per-spoke value from JSON, defaults to 128)
      ConfigReader.SpokeDeployConfig memory spokeCfg = json.readSpoke(s);
      ISpokeConfigurator(spokeConfigurator_).updateMaxReserves(
        spokeProxy,
        spokeCfg.maxUserReservesLimit
      );

      // Add reserves directly via SpokeConfigurator
      for (uint256 i; i < reserveCount; i++) {
        ConfigReader.ReserveConfig memory r = json.readReserve(i);
        if (!ScriptUtils.strEq(r.spokeKey, sKey)) continue;

        uint256 assetId = IHub(hub_).getAssetId(json.tokenAddress(r.assetKey));
        ISpokeConfigurator(spokeConfigurator_).addReserve(
          spokeProxy,
          hub_,
          assetId,
          json.tokenPriceFeed(r.assetKey),
          ISpoke.ReserveConfig({
            collateralRisk: r.collateralRisk,
            paused: r.paused,
            frozen: r.frozen,
            borrowable: r.borrowable,
            receiveSharesEnabled: r.receiveSharesEnabled
          }),
          ISpoke.DynamicReserveConfig({
            collateralFactor: r.collateralFactor,
            maxLiquidationBonus: r.maxLiquidationBonus,
            liquidationFee: r.liquidationFee
          })
        );
      }

      // Set liquidation config
      ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(s);
      if (lc.targetHealthFactor > 0) {
        ISpokeConfigurator(spokeConfigurator_).updateLiquidationConfig(spokeProxy, lc);
      }
    }
  }
}
