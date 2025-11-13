// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

library AaveV4SpokeConfigProcedures {
  function updateLiquidationConfig(
    ConfigData.UpdateLiquidationConfigParams memory params
  ) internal {
    ISpoke(params.spoke).updateLiquidationConfig(params.config);
  }

  function updateLiquidationConfigViaConfigurator(
    address configurator,
    ConfigData.UpdateLiquidationConfigParams memory params
  ) internal {
    ISpokeConfigurator(configurator).updateLiquidationConfig(params.spoke, params.config);
  }

  function addReserve(ConfigData.AddReserveParams memory params) internal returns (uint256) {
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
    ConfigData.AddReserveParams memory params
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
