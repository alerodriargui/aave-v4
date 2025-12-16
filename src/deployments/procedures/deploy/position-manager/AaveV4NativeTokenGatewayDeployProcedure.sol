// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';

contract AaveV4NativeTokenGatewayDeployProcedure {
  function _deployNativeTokenGateway(
    address nativeWrapper,
    address owner
  ) internal returns (address) {
    return address(new NativeTokenGateway({nativeWrapper_: nativeWrapper, initialOwner_: owner}));
  }
}
