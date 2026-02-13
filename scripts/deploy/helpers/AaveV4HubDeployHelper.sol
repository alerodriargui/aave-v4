// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'scripts/deploy/helpers/DeployHelpersBase.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';

/// @title AaveV4HubDeployHelper
/// @notice Hub-side deployment helpers: list assets on hubs, register spokes on hubs.
///         Can be used standalone (for hub-only operations) or inherited by a full deploy script.
/// @dev Follows V3 pattern: deployer holds temporary admin roles and calls HubConfigurator directly.
///      No config engine is deployed or used during deployment.
abstract contract AaveV4HubDeployHelper is DeployHelpersBase {
  using ConfigReader for string;

  /// @notice Lists assets on all hubs from the JSON config.
  /// @dev Deployer must hold HUB_CONFIGURATOR_ADMIN_ROLE to call HubConfigurator.
  function _listAssets(
    string memory json,
    ConfigReader.InfrastructureConfig memory infra,
    OrchestrationReports.FullDeploymentReport memory report,
    uint256 assetCount,
    uint256 hubCount
  ) internal {
    for (uint256 h; h < hubCount; h++) {
      string memory hKey = json.hubKey(h);
      address hub_ = report.hubBatchReports[h].report.hub;
      address hubConfigurator_ = report.configuratorBatchReport.hubConfigurator;
      address irStrategy_ = report.hubBatchReports[h].report.irStrategy;
      address treasurySpoke_ = report.hubBatchReports[h].report.treasurySpoke;

      for (uint256 i; i < assetCount; i++) {
        ConfigReader.AssetConfig memory a = json.readAsset(i);
        if (!ScriptUtils.strEq(a.hubKey, hKey)) continue;

        IHubConfigurator(hubConfigurator_).addAsset(
          hub_,
          json.tokenAddress(a.tokenKey),
          treasurySpoke_,
          a.liquidityFee,
          irStrategy_,
          abi.encode(a.irData)
        );
      }
    }
  }

  /// @notice Registers spokes on all hubs from the JSON config.
  /// @dev Deployer must hold HUB_CONFIGURATOR_ADMIN_ROLE. Tokenization spokes are deployed via CREATE2.
  function _registerSpokes(
    string memory json,
    ConfigReader.InfrastructureConfig memory infra,
    OrchestrationReports.FullDeploymentReport memory report,
    uint256 spokeRegistrationCount,
    uint256 hubCount,
    uint256 spokeCount
  ) internal {
    bytes32 deploySalt = keccak256(bytes(infra.salt));

    for (uint256 h; h < hubCount; h++) {
      string memory hKey = json.hubKey(h);
      address hub_ = report.hubBatchReports[h].report.hub;
      address hubConfigurator_ = report.configuratorBatchReport.hubConfigurator;

      for (uint256 i; i < spokeRegistrationCount; i++) {
        ConfigReader.SpokeRegistrationConfig memory reg = json.readSpokeRegistration(i);
        if (!ScriptUtils.strEq(reg.hubKey, hKey)) continue;

        address spokeAddr = _resolveSpokeAddress(json, report, reg.spokeKey, spokeCount);
        (bool tokenizeEnabled, ) = _findTokenization(json, reg.assetKey, hKey);
        uint256 assetId = IHub(hub_).getAssetId(json.tokenAddress(reg.assetKey));

        if (tokenizeEnabled) {
          string memory hubPrefix = ConfigReader.trimEnd(hKey, 4);
          address underlying = json.tokenAddress(reg.assetKey);

          // Deploy TokenizationSpokeInstance implementation
          bytes memory implBytecode = abi.encodePacked(
            type(TokenizationSpokeInstance).creationCode,
            abi.encode(hub_, assetId)
          );
          bytes32 implSalt = keccak256(
            abi.encodePacked(deploySalt, 'tokenization-impl', underlying)
          );
          address impl = Create2Utils.create2Deploy(implSalt, implBytecode);

          // Deploy proxy
          bytes32 proxySalt = keccak256(
            abi.encodePacked(deploySalt, 'tokenization-proxy', underlying)
          );
          spokeAddr = Create2Utils.proxify(
            proxySalt,
            impl,
            infra.spokeProxyAdminOwner,
            abi.encodeCall(
              TokenizationSpokeInstance.initialize,
              (
                string.concat(hubPrefix, ' ', reg.assetKey),
                string.concat('t', reg.assetKey, '-', hubPrefix)
              )
            )
          );
        }

        IHubConfigurator(hubConfigurator_).addSpoke(
          hub_,
          spokeAddr,
          assetId,
          IHub.SpokeConfig({
            addCap: reg.addCap,
            drawCap: reg.drawCap,
            riskPremiumThreshold: reg.riskPremiumThreshold,
            active: reg.active,
            halted: reg.halted
          })
        );
      }
    }
  }
}
