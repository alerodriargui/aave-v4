// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {console2 as console} from 'forge-std/console2.sol';

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

contract AaveV4SpokeInstanceBatch is
  AaveV4SpokeInstanceDeployProcedure,
  AaveV4TransparentUpgradeableProxyDeployProcedure,
  AaveV4AaveOracleDeployProcedure
{
  BatchReports.SpokeInstanceBatchReport internal _report;

  constructor(
    Vm vm_,
    address admin_,
    address accessManagerAddress_,
    uint8 oracleDecimals_,
    string memory oracleDescription_
  ) {
    address predictedSpokeInstanceAddress = vm_.computeCreateAddress(
      address(this),
      vm_.getNonce(address(this)) + 2
    );

    address aaveOracleAddress = _deployAaveOracle(
      predictedSpokeInstanceAddress,
      oracleDecimals_,
      oracleDescription_
    );
    address spokeImplementationAddress = _deploySpokeInstance(aaveOracleAddress);
    address spokeProxyAddress = _proxify(
      spokeImplementationAddress,
      admin_,
      abi.encodeWithSignature('initialize(address)', accessManagerAddress_)
    );

    require(spokeProxyAddress == predictedSpokeInstanceAddress, 'SpokeInstance address mismatch');

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
