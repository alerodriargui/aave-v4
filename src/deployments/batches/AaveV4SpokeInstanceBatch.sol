// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {Utils} from 'src/deployments/utils/libraries/Utils.sol';
import {
  AaveV4AaveOracleDeployProcedure
} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {
  AaveV4SpokeDeployProcedure
} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

contract AaveV4SpokeInstanceBatch is AaveV4SpokeDeployProcedure, AaveV4AaveOracleDeployProcedure {
  BatchReports.SpokeInstanceBatchReport internal _report;

  constructor(
    address spokeProxyAdminOwner_,
    address accessManager_,
    uint8 oracleDecimals_,
    string memory oracleDescription_
  ) {
    // additional 2 nonces for AaveOracle, SpokeInstance, starting from contract nonce of 1
    address predictedSpokeInstance = Utils.computeCreateAddress(address(this), 3);

    address aaveOracle = _deployAaveOracle(
      predictedSpokeInstance,
      oracleDecimals_,
      oracleDescription_
    );
    (address spokeProxy, address spokeImplementation) = _deployUpgradableSpokeInstance({
      spokeProxyAdminOwner: spokeProxyAdminOwner_,
      accessManager: accessManager_,
      oracle: aaveOracle
    });

    require(spokeProxy == predictedSpokeInstance, InvalidParam('predicted spoke instance'));
    require(ISpoke(spokeProxy).ORACLE() == aaveOracle, InvalidParam('spoke oracle'));
    require(IAaveOracle(aaveOracle).SPOKE() == spokeProxy, InvalidParam('aave oracle spoke'));

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracle: aaveOracle,
      spokeImplementation: spokeImplementation,
      spokeProxy: spokeProxy
    });
  }

  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
