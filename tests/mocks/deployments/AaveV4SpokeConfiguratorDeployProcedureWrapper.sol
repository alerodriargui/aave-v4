// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4SpokeConfiguratorDeployProcedure
} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4SpokeConfiguratorDeployProcedureWrapper is AaveV4SpokeConfiguratorDeployProcedure {
  function deploySpokeConfigurator(address owner) external returns (address) {
    return _deploySpokeConfigurator(owner);
  }
}
