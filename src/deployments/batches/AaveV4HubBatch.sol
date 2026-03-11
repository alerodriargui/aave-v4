// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';
import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';

contract AaveV4HubBatch is AaveV4HubDeployProcedure, AaveV4InterestRateStrategyDeployProcedure {
  BatchReports.HubBatchReport internal _report;

  constructor(address authority_, bytes memory hubBytecode_, bytes32 salt_) {
    address hub = _deployHub({authority: authority_, hubBytecode: hubBytecode_, salt: salt_});
    address irStrategy = _deployInterestRateStrategy({hub: hub, salt: salt_});

    _report = BatchReports.HubBatchReport({hub: hub, irStrategy: irStrategy});
  }

  function getReport() external view returns (BatchReports.HubBatchReport memory) {
    return _report;
  }
}
