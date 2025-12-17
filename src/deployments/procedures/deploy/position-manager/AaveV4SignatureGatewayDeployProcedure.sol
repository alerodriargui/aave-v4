// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4SignatureGatewayDeployProcedure is AaveV4DeployProcedureBase {
  function _deploySignatureGateway(address owner) internal returns (address) {
    _validateZeroAddress(owner, 'owner');
    return address(new SignatureGateway({initialOwner_: owner}));
  }
}
