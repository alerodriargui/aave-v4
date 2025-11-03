// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AssetInterestRateStrategy} from 'src/contracts/hub/AssetInterestRateStrategy.sol';

contract AaveV4InterestRateStrategyDeployProcedure {
  function _deployInterestRateStrategy(address hub_) internal returns (address) {
    address interestRateStrategy = address(new AssetInterestRateStrategy(hub_));

    return interestRateStrategy;
  }
}
