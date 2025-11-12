// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

library AaveV4SpokeConfigProcedures {
  struct UpdateLiquidationConfigParams {
    address spoke;
    ISpoke.LiquidationConfig config;
  }

  struct AddReserveParams {
    address spoke;
    address hub;
    uint256 assetId;
    address priceSource;
    ISpoke.ReserveConfig config;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  function updateLiquidationConfig(UpdateLiquidationConfigParams memory params) internal {
    ISpoke(params.spoke).updateLiquidationConfig(params.config);
  }

  function updateLiquidationConfigViaConfigurator(
    address configurator,
    UpdateLiquidationConfigParams memory params
  ) internal {
    ISpokeConfigurator(configurator).updateLiquidationConfig(params.spoke, params.config);
  }

  function addReserve(AddReserveParams memory params) internal returns (uint256) {
    return
      ISpoke(params.spoke).addReserve(
        params.hub,
        params.assetId,
        params.priceSource,
        params.config,
        params.dynamicConfig
      );
  }

  function addReserveViaConfigurator(
    address configurator,
    AddReserveParams memory params
  ) internal returns (uint256) {
    return
      ISpokeConfigurator(configurator).addReserve(
        params.spoke,
        params.hub,
        params.assetId,
        params.priceSource,
        params.config,
        params.dynamicConfig
      );
  }
}
