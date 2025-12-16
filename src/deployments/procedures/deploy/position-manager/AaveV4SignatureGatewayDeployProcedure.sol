// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';

contract AaveV4SignatureGatewayDeployProcedure {
  function _deploySignatureGateway(address owner) internal returns (address) {
    return address(new SignatureGateway({initialOwner_: owner}));
  }
}
