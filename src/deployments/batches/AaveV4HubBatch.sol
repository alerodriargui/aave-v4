// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/types/BatchReports.sol';
import {AaveV4HubDeployProcedure} from 'src/deployments/procedures/AaveV4HubDeployProcedure.sol';
import {AaveV4InterestRateStrategyDeployProcedure} from 'src/deployments/procedures/AaveV4InterestRateStrategyDeployProcedure.sol';
import {AaveV4TreasurySpokeDeployProcedure} from 'src/deployments/procedures/AaveV4TreasurySpokeDeployProcedure.sol';

contract AaveV4HubBatch is
  AaveV4HubDeployProcedure,
  AaveV4InterestRateStrategyDeployProcedure,
  AaveV4TreasurySpokeDeployProcedure
{
  BatchReports.HubBatchReport internal _report;

  constructor(address admin_, address accessManagerAddress_) {
    address hubAddress = _deployHub(accessManagerAddress_);
    address irStrategyAddress = _deployInterestRateStrategy(hubAddress);
    address treasurySpokeAddress = _deployTreasurySpoke(admin_, hubAddress);

    _report = BatchReports.HubBatchReport({
      hubAddress: hubAddress,
      irStrategyAddress: irStrategyAddress,
      treasurySpokeAddress: treasurySpokeAddress
    });
  }

  function getReport() external view returns (BatchReports.HubBatchReport memory) {
    return _report;
  }
}
