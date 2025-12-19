// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Hub} from 'src/hub/Hub.sol';
import {
  Create2Utils,
  AaveV4DeployProcedureBase
} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHub(address accessManager) internal returns (address) {
    require(accessManager != address(0), 'invalid access manager');
    return
      Create2Utils.create2Deploy(
        SALT,
        abi.encodePacked(type(Hub).creationCode, abi.encode(accessManager))
      );
  }
}
