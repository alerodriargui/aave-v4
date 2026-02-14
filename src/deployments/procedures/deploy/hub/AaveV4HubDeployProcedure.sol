// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

contract AaveV4HubDeployProcedure is AaveV4DeployProcedureBase {
  function _deployHub(
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (address) {
    require(authority != address(0), 'invalid authority');
    return Create2Utils.create2Deploy(salt, _getHubInitCode(hubBytecode, authority));
  }

  function _getHubInitCode(
    bytes memory hubBytecode,
    address authority
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(hubBytecode, abi.encode(authority));
  }
}
