// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4HubDeployProcedure
} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';

contract AaveV4HubDeployProcedureWrapper is AaveV4HubDeployProcedure {
  bool public IS_TEST = true;

  function deployHub(address accessManager) external returns (address) {
    return _deployHub(accessManager);
  }
}
