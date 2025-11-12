// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

library AaveV4HubConfigProcedures {
  struct AddAssetParams {
    address hub;
    address underlying;
    uint8 decimals;
    address feeReceiver;
    uint16 liquidityFee;
    address irStrategy;
    bytes irData;
  }

  struct UpdateAssetConfigParams {
    address hub;
    uint256 assetId;
    IHub.AssetConfig config;
    bytes irData;
  }

  struct AddSpokeParams {
    address hub;
    uint256 assetId;
    address spoke;
    IHub.SpokeConfig config;
  }

  struct AddSpokeToAssetsParams {
    address hub;
    address spoke;
    uint256[] assetIds;
    IHub.SpokeConfig[] configs;
  }

  function addAsset(AddAssetParams memory params) internal returns (uint256) {
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
    AddAssetParams memory params
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

  function updateAssetConfig(UpdateAssetConfigParams memory params) internal {
    IHub(params.hub).updateAssetConfig(params.assetId, params.config, params.irData);
  }

  function addSpoke(AddSpokeParams memory params) internal {
    IHub(params.hub).addSpoke(params.assetId, params.spoke, params.config);
  }

  function addSpokeViaConfigurator(address configurator, AddSpokeParams memory params) internal {
    IHubConfigurator(configurator).addSpoke(
      params.hub,
      params.spoke,
      params.assetId,
      params.config
    );
  }

  function addSpokeToAssets(address configurator, AddSpokeToAssetsParams memory params) internal {
    IHubConfigurator(configurator).addSpokeToAssets(
      params.hub,
      params.spoke,
      params.assetIds,
      params.configs
    );
  }
}
