// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DeployHelpersBase} from 'scripts/deploy/helpers/DeployHelpersBase.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ScriptUtils} from 'scripts/ScriptUtils.sol';

import {AaveV4SpokeConfigEngine} from 'src/deployments/config-engine/AaveV4SpokeConfigEngine.sol';
import {IAaveV4SpokeConfigEngine} from 'src/deployments/config-engine/IAaveV4SpokeConfigEngine.sol';

/// @title AaveV4SpokeDeployHelper
/// @notice Spoke-side deployment helpers: configure reserves on spokes, set liquidation configs.
///         Can be used standalone (for spoke-only operations) or inherited by a full deploy script.
/// @dev The SpokeConfigEngine is stateless — a single instance is deployed and reused across all spokes.
///      The engine is granted SPOKE_CONFIGURATOR_ADMIN_ROLE (+ FREEZE/PAUSE) so its calls to
///      SpokeConfigurator are authorized.
abstract contract AaveV4SpokeDeployHelper is DeployHelpersBase {
  using ConfigReader for string;

  /// @notice Configures reserves on all spokes from the JSON config.
  /// @dev Deploys a single stateless SpokeConfigEngine, grants it roles, and configures each spoke.
  function _configureReserves(
    string memory json,
    OrchestrationReports.FullDeploymentReport memory report,
    uint256 reserveCount,
    uint256 spokeCount,
    uint256 hubCount
  ) internal {
    address accessManager = report.accessBatchReport.accessManager;
    address spokeConfigurator_ = report.configuratorBatchReport.spokeConfigurator;

    // Deploy stateless engine once and grant it roles
    AaveV4SpokeConfigEngine spokeEngine = new AaveV4SpokeConfigEngine();
    IAccessManager(accessManager).grantRole(
      Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE,
      address(spokeEngine),
      0
    );
    IAccessManager(accessManager).grantRole(Roles.SPOKE_FREEZE_ROLE, address(spokeEngine), 0);
    IAccessManager(accessManager).grantRole(Roles.SPOKE_PAUSE_ROLE, address(spokeEngine), 0);

    for (uint256 s; s < spokeCount; s++) {
      string memory sKey = json.spokeKey(s);
      address spokeProxy = report.spokeInstanceBatchReports[s].report.spokeProxy;

      // Find the hub this spoke's reserves reference
      address hub_ = _findHubForSpoke(json, report, sKey, reserveCount, hubCount);
      if (hub_ == address(0)) continue;

      // Count reserves for this spoke
      uint256 count;
      for (uint256 i; i < reserveCount; i++) {
        ConfigReader.ReserveConfig memory r = json.readReserve(i);
        if (ScriptUtils.strEq(r.spokeKey, sKey)) count++;
      }
      if (count == 0) continue;

      // Set maxReserves from spoke config (per-spoke value from JSON, defaults to 128)
      ConfigReader.SpokeDeployConfig memory spokeCfg = json.readSpoke(s);
      ISpokeConfigurator(spokeConfigurator_).updateMaxReserves(
        spokeProxy,
        spokeCfg.maxUserReservesLimit
      );

      // Build reserve listings
      IAaveV4SpokeConfigEngine.ReserveListing[]
        memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](count);
      uint256 idx;
      for (uint256 i; i < reserveCount; i++) {
        ConfigReader.ReserveConfig memory r = json.readReserve(i);
        if (!ScriptUtils.strEq(r.spokeKey, sKey)) continue;

        reserves[idx] = IAaveV4SpokeConfigEngine.ReserveListing({
          underlying: json.tokenAddress(r.assetKey),
          priceFeed: json.tokenPriceFeed(r.assetKey),
          config: ISpoke.ReserveConfig({
            collateralRisk: r.collateralRisk,
            paused: r.paused,
            frozen: r.frozen,
            borrowable: r.borrowable,
            receiveSharesEnabled: r.receiveSharesEnabled
          }),
          dynamicConfig: ISpoke.DynamicReserveConfig({
            collateralFactor: r.collateralFactor,
            maxLiquidationBonus: r.maxLiquidationBonus,
            liquidationFee: r.liquidationFee
          })
        });
        idx++;
      }

      spokeEngine.listReserves(spokeProxy, spokeConfigurator_, hub_, reserves);

      // Set liquidation config
      ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(s);
      if (lc.targetHealthFactor > 0) {
        spokeEngine.updateLiquidationConfig(
          spokeProxy,
          spokeConfigurator_,
          IAaveV4SpokeConfigEngine.LiquidationConfigInput({config: lc})
        );
      }
    }
  }
}
