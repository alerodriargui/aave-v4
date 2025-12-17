// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {HubConfigurator} from 'src/hub/HubConfigurator.sol';
import {
  Create2Utils,
  AaveV4DeployProcedureBase
} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4HubConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHubConfigurator(address owner) internal returns (address) {
    _validateZeroAddress(owner, 'owner');
    return
      Create2Utils.create2Deploy(
        SALT,
        abi.encodePacked(type(HubConfigurator).creationCode, abi.encode(owner))
      );
  }
}
