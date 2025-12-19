// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {
  Create2Utils,
  AaveV4DeployProcedureBase
} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4NativeTokenGatewayDeployProcedure is AaveV4DeployProcedureBase {
  function _deployNativeTokenGateway(
    address nativeWrapper,
    address owner
  ) internal returns (address) {
    require(nativeWrapper != address(0), 'invalid native wrapper');
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy(
        SALT,
        abi.encodePacked(type(NativeTokenGateway).creationCode, abi.encode(nativeWrapper, owner))
      );
  }
}
