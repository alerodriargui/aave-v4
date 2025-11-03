// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SignatureGateway} from 'src/contracts/position-manager/SignatureGateway.sol';

contract AaveV4SignatureGatewayDeployProcedure {
  function _deploySignatureGateway(address owner_) internal returns (address) {
    address signatureGateway = address(new SignatureGateway(owner_));

    return signatureGateway;
  }
}
