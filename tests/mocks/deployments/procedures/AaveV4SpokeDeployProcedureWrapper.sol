// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4SpokeDeployProcedure
} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

contract AaveV4SpokeDeployProcedureWrapper is AaveV4SpokeDeployProcedure {
  bool public IS_TEST = true;

  function deployUpgradableSpokeInstance(
    address spokeProxyAdminOwner,
    address accessManager,
    address oracle
  ) external returns (address spokeProxy, address spokeImplementation) {
    return _deployUpgradableSpokeInstance(spokeProxyAdminOwner, accessManager, oracle);
  }
}
