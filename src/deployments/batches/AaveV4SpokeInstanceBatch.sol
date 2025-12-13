// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {
  AaveV4SpokeInstanceDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4SpokeInstanceDeployProcedure.sol';
import {
  AaveV4TransparentUpgradeableProxyDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4TransparentUpgradeableProxyDeployProcedure.sol';
import {
  AaveV4AaveOracleDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4AaveOracleDeployProcedure.sol';
import {Utils} from 'src/deployments/utils/libraries/Utils.sol';

contract AaveV4SpokeInstanceBatch is
  AaveV4SpokeInstanceDeployProcedure,
  AaveV4TransparentUpgradeableProxyDeployProcedure,
  AaveV4AaveOracleDeployProcedure
{
  BatchReports.SpokeInstanceBatchReport internal _report;

  constructor(
    address spokeProxyAdminOwner_,
    address accessManagerAddress_,
    uint8 oracleDecimals_,
    string memory oracleDescription_
  ) {
    // additional 2 nonces for AaveOracle, SpokeInstance, starting from contract nonce of 1
    address predictedSpokeInstanceAddress = Utils.computeCreateAddress(address(this), 3);

    address aaveOracleAddress = _deployAaveOracle(
      predictedSpokeInstanceAddress,
      oracleDecimals_,
      oracleDescription_
    );
    address spokeImplementationAddress = _deploySpokeInstance(aaveOracleAddress);
    address spokeProxyAddress = _proxify(
      spokeImplementationAddress,
      spokeProxyAdminOwner_,
      abi.encodeWithSignature('initialize(address)', accessManagerAddress_)
    );

    assert(spokeProxyAddress == predictedSpokeInstanceAddress);

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracleAddress: aaveOracleAddress,
      spokeImplementationAddress: spokeImplementationAddress,
      spokeProxyAddress: spokeProxyAddress
    });
  }

  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
