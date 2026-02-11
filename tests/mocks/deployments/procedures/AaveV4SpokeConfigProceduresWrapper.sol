// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4SpokeConfigProcedures} from 'src/deployments/procedures/config/AaveV4SpokeConfigProcedures.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

contract AaveV4SpokeConfigProceduresWrapper {
  bool public IS_TEST = true;

  function addReserve(ConfigData.AddReserveParams memory params) external returns (uint256) {
    return AaveV4SpokeConfigProcedures.addReserve(params);
  }

  function addReserveViaConfigurator(
    address configurator,
    ConfigData.AddReserveParams memory params
  ) external returns (uint256) {
    return AaveV4SpokeConfigProcedures.addReserveViaConfigurator(configurator, params);
  }

  function updateLiquidationConfig(
    ConfigData.UpdateLiquidationConfigParams memory params
  ) external {
    AaveV4SpokeConfigProcedures.updateLiquidationConfig(params);
  }

  function updateLiquidationConfigViaConfigurator(
    address configurator,
    ConfigData.UpdateLiquidationConfigParams memory params
  ) external {
    AaveV4SpokeConfigProcedures.updateLiquidationConfigViaConfigurator(configurator, params);
  }
}
