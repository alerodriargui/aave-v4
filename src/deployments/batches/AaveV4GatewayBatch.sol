// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {
  AaveV4NativeTokenGatewayDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {
  AaveV4SignatureGatewayDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4GatewayBatch is
  AaveV4NativeTokenGatewayDeployProcedure,
  AaveV4SignatureGatewayDeployProcedure
{
  BatchReports.GatewaysBatchReport internal _report;

  constructor(address owner_, address nativeWrapper_) {
    address nativeGatewayAddress;
    if (nativeWrapper_ != address(0)) {
      nativeGatewayAddress = _deployNativeTokenGateway({
        nativeWrapper_: nativeWrapper_,
        owner_: owner_
      });
    }
    address signatureGatewayAddress = _deploySignatureGateway(owner_);

    _report = BatchReports.GatewaysBatchReport({
      nativeGatewayAddress: nativeGatewayAddress,
      signatureGatewayAddress: signatureGatewayAddress
    });
  }

  function getReport() external view returns (BatchReports.GatewaysBatchReport memory) {
    return _report;
  }
}
