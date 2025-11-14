// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';

contract AaveV4InterestRateStrategyDeployProcedure {
  function _deployInterestRateStrategy(address hub_) internal returns (address) {
    address interestRateStrategy = address(new AssetInterestRateStrategy(hub_));

    return interestRateStrategy;
  }
}
