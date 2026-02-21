// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';

library AaveV4HubConfigProcedures {
  function addAssetViaConfigurator(
    address configurator,
    ConfigData.AddAssetParams memory params
  ) internal returns (uint256) {
    return
      IHubConfigurator(configurator).addAssetWithDecimals({
        hub: params.hub,
        underlying: params.underlying,
        decimals: params.decimals,
        feeReceiver: params.feeReceiver,
        liquidityFee: params.liquidityFee,
        irStrategy: params.irStrategy,
        irData: params.irData
      });
  }

  function addSpokeViaConfigurator(
    address configurator,
    ConfigData.AddSpokeParams memory params
  ) internal {
    IHubConfigurator(configurator).addSpoke({
      hub: params.hub,
      spoke: params.spoke,
      assetId: params.assetId,
      config: params.config
    });
  }

  function addSpokeToAssetsViaConfigurator(
    address configurator,
    ConfigData.AddSpokeToAssetsParams memory params
  ) internal {
    IHubConfigurator(configurator).addSpokeToAssets({
      hub: params.hub,
      spoke: params.spoke,
      assetIds: params.assetIds,
      configs: params.configs
    });
  }
}
