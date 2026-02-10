// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHub(address accessManager, bytes32 salt) internal returns (address) {
    require(accessManager != address(0), 'invalid access manager');
    return Create2Utils.create2Deploy(salt, _getHubInitCode(accessManager));
  }

  function _getHubInitCode(address authority) internal view returns (bytes memory) {
    return abi.encodePacked(vm.getCode('src/hub/Hub.sol:Hub'), abi.encode(authority));
  }
}
