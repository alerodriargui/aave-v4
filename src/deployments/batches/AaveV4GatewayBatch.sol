// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {
  AaveV4NativeTokenGatewayDeployProcedure
} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {
  AaveV4SignatureGatewayDeployProcedure
} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4GatewayBatch is
  AaveV4NativeTokenGatewayDeployProcedure,
  AaveV4SignatureGatewayDeployProcedure
{
  BatchReports.GatewaysBatchReport internal _report;

  constructor(address owner_, address nativeWrapper_) {
    assert(owner_ != address(0));
    assert(nativeWrapper_ != address(0));

    address nativeGateway = _deployNativeTokenGateway({
      nativeWrapper: nativeWrapper_,
      owner: owner_
    });
    address signatureGateway = _deploySignatureGateway(owner_);

    _report = BatchReports.GatewaysBatchReport({
      nativeGateway: nativeGateway,
      signatureGateway: signatureGateway
    });
  }

  function getReport() external view returns (BatchReports.GatewaysBatchReport memory) {
    return _report;
  }
}
