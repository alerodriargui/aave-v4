// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4HubConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/hub/AaveV4HubConfiguratorDeployProcedure.sol';
import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4ConfiguratorBatch is
  AaveV4HubConfiguratorDeployProcedure,
  AaveV4SpokeConfiguratorDeployProcedure
{
  BatchReports.ConfiguratorBatchReport internal _report;

  constructor(
    address hubConfiguratorAuthority_,
    address spokeConfiguratorAuthority_,
    bytes32 salt_
  ) {
    address hubConfigurator = _deployHubConfigurator(
      hubConfiguratorAuthority_,
      keccak256(abi.encodePacked(SALT, salt_, 'hubConfigurator'))
    );
    address spokeConfigurator = _deploySpokeConfigurator(
      spokeConfiguratorAuthority_,
      keccak256(abi.encodePacked(SALT, salt_, 'spokeConfigurator'))
    );

    _report = BatchReports.ConfiguratorBatchReport({
      hubConfigurator: hubConfigurator,
      spokeConfigurator: spokeConfigurator
    });
  }

  function getReport() external view returns (BatchReports.ConfiguratorBatchReport memory) {
    return _report;
  }
}
