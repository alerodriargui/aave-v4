// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4NativeTokenGatewayDeployProcedure is AaveV4DeployProcedureBase {
  function _deployNativeTokenGateway(
    address nativeWrapper,
    address owner
  ) internal returns (address) {
    _validateAddress(nativeWrapper, 'native wrapper');
    _validateAddress(owner, 'owner');
    return address(new NativeTokenGateway({nativeWrapper_: nativeWrapper, initialOwner_: owner}));
  }
}
