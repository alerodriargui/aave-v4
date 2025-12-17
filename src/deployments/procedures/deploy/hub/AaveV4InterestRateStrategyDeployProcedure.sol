// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4InterestRateStrategyDeployProcedure is AaveV4DeployProcedureBase {
  function _deployInterestRateStrategy(address hub) internal returns (address) {
    require(hub != address(0), InvalidParam('hub'));
    return address(new AssetInterestRateStrategy({hub_: hub}));
  }
}
