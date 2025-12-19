// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {
  Create2Utils,
  AaveV4DeployProcedureBase
} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4SignatureGatewayDeployProcedure is AaveV4DeployProcedureBase {
  function _deploySignatureGateway(address owner) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy(
        SALT,
        abi.encodePacked(type(SignatureGateway).creationCode, abi.encode(owner))
      );
  }
}
