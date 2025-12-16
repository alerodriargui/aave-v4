// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {
  AaveV4HubDeployProcedure
} from 'src/deployments/procedures/deploy/hub/AaveV4HubDeployProcedure.sol';
import {
  AaveV4InterestRateStrategyDeployProcedure
} from 'src/deployments/procedures/deploy/hub/AaveV4InterestRateStrategyDeployProcedure.sol';
import {
  AaveV4TreasurySpokeDeployProcedure
} from 'src/deployments/procedures/deploy/spoke/AaveV4TreasurySpokeDeployProcedure.sol';

contract AaveV4HubBatch is
  AaveV4HubDeployProcedure,
  AaveV4InterestRateStrategyDeployProcedure,
  AaveV4TreasurySpokeDeployProcedure
{
  BatchReports.HubBatchReport internal _report;

  constructor(address treasurySpokeOwner_, address accessManager_) {
    assert(treasurySpokeOwner_ != address(0));
    assert(accessManager_ != address(0));

    address hub = _deployHub(accessManager_);
    address irStrategy = _deployInterestRateStrategy(hub);
    address treasurySpoke = _deployTreasurySpoke(treasurySpokeOwner_, hub);

    _report = BatchReports.HubBatchReport({
      hub: hub,
      irStrategy: irStrategy,
      treasurySpoke: treasurySpoke
    });
  }

  function getReport() external view returns (BatchReports.HubBatchReport memory) {
    return _report;
  }
}
