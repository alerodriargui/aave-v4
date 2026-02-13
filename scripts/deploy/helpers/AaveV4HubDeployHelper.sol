// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DeployHelpersBase} from 'scripts/deploy/helpers/DeployHelpersBase.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ScriptUtils} from 'scripts/ScriptUtils.sol';

import {AaveV4HubConfigEngine} from 'src/deployments/config-engine/AaveV4HubConfigEngine.sol';
import {IAaveV4HubConfigEngine} from 'src/deployments/config-engine/IAaveV4HubConfigEngine.sol';

/// @title AaveV4HubDeployHelper
/// @notice Hub-side deployment helpers: list assets on hubs, register spokes on hubs.
///         Can be used standalone (for hub-only operations) or inherited by a full deploy script.
/// @dev The HubConfigEngine is stateless — a single instance is deployed and reused across all hubs.
///      The engine is granted HUB_CONFIGURATOR_ADMIN_ROLE so its calls to HubConfigurator are authorized.
abstract contract AaveV4HubDeployHelper is DeployHelpersBase {
  using ConfigReader for string;

  /// @notice Lists assets on all hubs from the JSON config.
  /// @dev Deploys a single stateless HubConfigEngine, grants it the admin role, and calls listAssets per hub.
  function _listAssets(
    string memory json,
    ConfigReader.InfrastructureConfig memory infra,
    OrchestrationReports.FullDeploymentReport memory report,
    uint256 assetCount,
    uint256 hubCount
  ) internal {
    address accessManager = report.accessBatchReport.accessManager;

    // Deploy stateless engine once and grant it the admin role
    AaveV4HubConfigEngine hubEngine = new AaveV4HubConfigEngine();
    IAccessManager(accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
      address(hubEngine),
      0
    );

    for (uint256 h; h < hubCount; h++) {
      string memory hKey = json.hubKey(h);
      address hub_ = report.hubBatchReports[h].report.hub;
      address hubConfigurator_ = report.configuratorBatchReport.hubConfigurator;
      address irStrategy_ = report.hubBatchReports[h].report.irStrategy;
      address treasurySpoke_ = report.hubBatchReports[h].report.treasurySpoke;

      // Count assets for this hub
      uint256 count;
      for (uint256 i; i < assetCount; i++) {
        ConfigReader.AssetConfig memory a = json.readAsset(i);
        if (ScriptUtils.strEq(a.hubKey, hKey)) count++;
      }
      if (count == 0) continue;

      // Build listings
      IAaveV4HubConfigEngine.AssetListing[]
        memory listings = new IAaveV4HubConfigEngine.AssetListing[](count);
      uint256 idx;
      for (uint256 i; i < assetCount; i++) {
        ConfigReader.AssetConfig memory a = json.readAsset(i);
        if (!ScriptUtils.strEq(a.hubKey, hKey)) continue;

        listings[idx] = IAaveV4HubConfigEngine.AssetListing({
          underlying: json.tokenAddress(a.tokenKey),
          irStrategy: irStrategy_,
          irData: abi.encode(a.irData),
          liquidityFee: a.liquidityFee,
          feeReceiver: treasurySpoke_,
          reinvestmentController: address(0)
        });
        idx++;
      }

      hubEngine.listAssets(hub_, hubConfigurator_, listings);
    }
  }

  /// @notice Registers spokes on all hubs from the JSON config.
  /// @dev Deploys a single stateless HubConfigEngine, grants it the admin role, and calls addSpokes per hub.
  function _registerSpokes(
    string memory json,
    ConfigReader.InfrastructureConfig memory infra,
    OrchestrationReports.FullDeploymentReport memory report,
    uint256 spokeRegistrationCount,
    uint256 hubCount,
    uint256 spokeCount
  ) internal {
    address accessManager = report.accessBatchReport.accessManager;

    // Deploy stateless engine once and grant it the admin role
    AaveV4HubConfigEngine hubEngine = new AaveV4HubConfigEngine();
    IAccessManager(accessManager).grantRole(
      Roles.HUB_CONFIGURATOR_ADMIN_ROLE,
      address(hubEngine),
      0
    );

    bytes32 deploySalt = keccak256(bytes(infra.salt));

    for (uint256 h; h < hubCount; h++) {
      string memory hKey = json.hubKey(h);
      address hub_ = report.hubBatchReports[h].report.hub;
      address hubConfigurator_ = report.configuratorBatchReport.hubConfigurator;

      // Count registrations for this hub
      uint256 count;
      for (uint256 i; i < spokeRegistrationCount; i++) {
        ConfigReader.SpokeRegistrationConfig memory reg = json.readSpokeRegistration(i);
        if (ScriptUtils.strEq(reg.hubKey, hKey)) count++;
      }
      if (count == 0) continue;

      // Build spoke listings
      IAaveV4HubConfigEngine.SpokeListing[]
        memory spokeListings = new IAaveV4HubConfigEngine.SpokeListing[](count);
      uint256 idx;
      for (uint256 i; i < spokeRegistrationCount; i++) {
        ConfigReader.SpokeRegistrationConfig memory reg = json.readSpokeRegistration(i);
        if (!ScriptUtils.strEq(reg.hubKey, hKey)) continue;

        address spokeAddr = _resolveSpokeAddress(json, report, reg.spokeKey, spokeCount);
        (bool tokenizeEnabled, ) = _findTokenization(json, reg.assetKey, hKey);
        string memory hubPrefix = ConfigReader.trimEnd(hKey, 4); // e.g. "PRIME_HUB" → "PRIME"

        spokeListings[idx] = IAaveV4HubConfigEngine.SpokeListing({
          underlying: json.tokenAddress(reg.assetKey),
          spoke: tokenizeEnabled ? address(0) : spokeAddr,
          tokenization: IAaveV4HubConfigEngine.TokenizationConfig({
            enabled: tokenizeEnabled,
            shareName: string.concat(hubPrefix, ' ', reg.assetKey),
            shareSymbol: string.concat('t', reg.assetKey, '-', hubPrefix),
            proxyAdminOwner: infra.spokeProxyAdminOwner
          }),
          spokeConfig: IHub.SpokeConfig({
            addCap: reg.addCap,
            drawCap: reg.drawCap,
            riskPremiumThreshold: reg.riskPremiumThreshold,
            active: reg.active,
            halted: reg.halted
          })
        });
        idx++;
      }

      hubEngine.addSpokes(hub_, hubConfigurator_, deploySalt, spokeListings);
    }
  }
}
