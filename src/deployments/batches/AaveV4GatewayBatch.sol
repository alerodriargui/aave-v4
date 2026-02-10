// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4NativeTokenGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4NativeTokenGatewayDeployProcedure.sol';
import {AaveV4SignatureGatewayDeployProcedure} from 'src/deployments/procedures/deploy/position-manager/AaveV4SignatureGatewayDeployProcedure.sol';

contract AaveV4GatewayBatch is
  AaveV4NativeTokenGatewayDeployProcedure,
  AaveV4SignatureGatewayDeployProcedure
{
  BatchReports.GatewaysBatchReport internal _report;

  constructor(address owner_, address nativeWrapper_, bytes32 salt_) {
    address nativeGateway = _deployNativeTokenGateway({
      nativeWrapper: nativeWrapper_,
      owner: owner_,
      salt: keccak256(abi.encodePacked(SALT, salt_, 'nativeGateway'))
    });
    address signatureGateway = _deploySignatureGateway(
      owner_,
      keccak256(abi.encodePacked(SALT, salt_, 'signatureGateway'))
    );

    _report = BatchReports.GatewaysBatchReport({
      nativeGateway: nativeGateway,
      signatureGateway: signatureGateway
    });
  }

  function getReport() external view returns (BatchReports.GatewaysBatchReport memory) {
    return _report;
  }
}
