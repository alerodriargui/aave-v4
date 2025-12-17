// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Hub} from 'src/hub/Hub.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHub(address accessManager) internal returns (address) {
    _validateAddress(accessManager, 'access manager');
    return address(new Hub({authority_: accessManager}));
  }
}
