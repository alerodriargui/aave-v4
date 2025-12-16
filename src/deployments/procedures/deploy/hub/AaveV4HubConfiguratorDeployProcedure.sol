// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {HubConfigurator} from 'src/hub/HubConfigurator.sol';

contract AaveV4HubConfiguratorDeployProcedure {
  function _deployHubConfigurator(address owner) internal returns (address) {
    return address(new HubConfigurator({owner_: owner}));
  }
}
