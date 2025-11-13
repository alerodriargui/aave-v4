// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

library AaveV4HubConfigProcedures {
  function addAsset(ConfigData.AddAssetParams memory params) internal returns (uint256) {
    uint256 assetId = IHub(params.hub).addAsset(
      params.underlying,
      params.decimals,
      params.feeReceiver,
      params.irStrategy,
      params.irData
    );
    if (params.liquidityFee > 0) {
      IHub(params.hub).updateAssetConfig(
        assetId,
        IHub.AssetConfig({
          liquidityFee: params.liquidityFee,
          feeReceiver: params.feeReceiver,
          irStrategy: params.irStrategy,
          reinvestmentController: address(0)
        }),
        new bytes(0)
      );
    }
    return assetId;
  }

  function addAssetViaConfigurator(
    address configurator,
    ConfigData.AddAssetParams memory params
  ) internal returns (uint256) {
    return
      IHubConfigurator(configurator).addAsset(
        params.hub,
        params.underlying,
        params.decimals,
        params.feeReceiver,
        params.liquidityFee,
        params.irStrategy,
        params.irData
      );
  }

  function updateAssetConfig(ConfigData.UpdateAssetConfigParams memory params) internal {
    IHub(params.hub).updateAssetConfig(params.assetId, params.config, params.irData);
  }

  function addSpoke(ConfigData.AddSpokeParams memory params) internal {
    IHub(params.hub).addSpoke(params.assetId, params.spoke, params.config);
  }

  function addSpokeViaConfigurator(
    address configurator,
    ConfigData.AddSpokeParams memory params
  ) internal {
    IHubConfigurator(configurator).addSpoke(
      params.hub,
      params.spoke,
      params.assetId,
      params.config
    );
  }

  function addSpokeToAssets(
    address configurator,
    ConfigData.AddSpokeToAssetsParams memory params
  ) internal {
    IHubConfigurator(configurator).addSpokeToAssets(
      params.hub,
      params.spoke,
      params.assetIds,
      params.configs
    );
  }
}
