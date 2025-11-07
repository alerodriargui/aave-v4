// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/types/BatchReports.sol';
import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4GatewaysBatch is
  AaveV4NativeTokenGatewayDeployProcedure,
  AaveV4SignatureGatewayDeployProcedure
{
  BatchReports.GatewaysBatchReport internal _report;

  constructor(address admin_, address nativeWrapper_) {
    address nativeGatewayAddress = _deployNativeTokenGateway(nativeWrapper_, admin_);
    address signatureGatewayAddress = _deploySignatureGateway(admin_);

    _report = BatchReports.GatewaysBatchReport({
      nativeGatewayAddress: nativeGatewayAddress,
      signatureGatewayAddress: signatureGatewayAddress
    });
  }

  function getReport() external view returns (BatchReports.GatewaysBatchReport memory) {
    return _report;
  }
}
