// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

library AaveV4SpokeConfigProcedures {
  function updateLiquidationConfigViaConfigurator(
    address configurator,
    ConfigData.UpdateLiquidationConfigParams memory params
  ) internal {
    ISpokeConfigurator(configurator).updateLiquidationConfig({
      spoke: params.spoke,
      liquidationConfig: params.config
    });
  }
  function addReserveViaConfigurator(
    address configurator,
    ConfigData.AddReserveParams memory params
  ) internal returns (uint256) {
    return
      ISpokeConfigurator(configurator).addReserve({
        spoke: params.spoke,
        hub: params.hub,
        assetId: params.assetId,
        priceSource: params.priceSource,
        config: params.config,
        dynamicConfig: params.dynamicConfig
      });
  }
}
