// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4HubConfiguratorDeployProcedure.sol';
import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4ConfiguratorBatch is
  AaveV4HubConfiguratorDeployProcedure,
  AaveV4SpokeConfiguratorDeployProcedure
{
  BatchReports.ConfiguratorBatchReport internal _report;

  constructor(address admin_) {
    address hubConfiguratorAddress = _deployHubConfigurator(admin_);
    address spokeConfiguratorAddress = _deploySpokeConfigurator(admin_);

    _report = BatchReports.ConfiguratorBatchReport({
      hubConfiguratorAddress: hubConfiguratorAddress,
      spokeConfiguratorAddress: spokeConfiguratorAddress
    });
  }

  function getReport() external view returns (BatchReports.ConfiguratorBatchReport memory) {
    return _report;
  }
}
