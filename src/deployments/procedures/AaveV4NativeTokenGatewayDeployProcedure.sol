// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {NativeTokenGateway} from 'src/contracts/position-manager/NativeTokenGateway.sol';

contract AaveV4NativeTokenGatewayDeployProcedure {
  function _deployNativeTokenGateway(
    address nativeWrapper_,
    address owner_
  ) internal returns (address) {
    address nativeTokenGateway = address(new NativeTokenGateway(nativeWrapper_, owner_));

    return nativeTokenGateway;
  }
}
