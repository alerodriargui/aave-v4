// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {Hub} from 'src/hub/Hub.sol';

contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHub(address accessManager, bytes32 salt) internal returns (address) {
    require(accessManager != address(0), 'invalid access manager');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(Hub).creationCode, abi.encode(accessManager))
      );
  }
}
