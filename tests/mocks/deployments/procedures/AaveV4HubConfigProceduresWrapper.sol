// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubConfigProcedures} from 'src/deployments/procedures/config/AaveV4HubConfigProcedures.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

contract AaveV4HubConfigProceduresWrapper {
  bool public IS_TEST = true;

  function addAsset(ConfigData.AddAssetParams memory params) external returns (uint256) {
    return AaveV4HubConfigProcedures.addAsset(params);
  }

  function addAssetViaConfigurator(
    address configurator,
    ConfigData.AddAssetParams memory params
  ) external returns (uint256) {
    return AaveV4HubConfigProcedures.addAssetViaConfigurator(configurator, params);
  }

  function updateAssetConfig(ConfigData.UpdateAssetConfigParams memory params) external {
    AaveV4HubConfigProcedures.updateAssetConfig(params);
  }

  function addSpoke(ConfigData.AddSpokeParams memory params) external {
    AaveV4HubConfigProcedures.addSpoke(params);
  }

  function addSpokeViaConfigurator(
    address configurator,
    ConfigData.AddSpokeParams memory params
  ) external {
    AaveV4HubConfigProcedures.addSpokeViaConfigurator(configurator, params);
  }

  function addSpokeToAssetsViaConfigurator(
    address configurator,
    ConfigData.AddSpokeToAssetsParams memory params
  ) external {
    AaveV4HubConfigProcedures.addSpokeToAssetsViaConfigurator(configurator, params);
  }
}
