// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4SignatureGatewayDeployProcedure
} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4SignatureGatewayDeployProcedureWrapper is AaveV4SignatureGatewayDeployProcedure {
  function deploySignatureGateway(address owner) external returns (address) {
    return _deploySignatureGateway(owner);
  }
}
