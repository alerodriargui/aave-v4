// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {SpokeUtils} from '../../src/spoke/libraries/SpokeUtils.sol';

contract SpokeHarness is SpokeInstance {
  constructor(address oracle_) SpokeInstance(oracle_) {}

  function calculateDebtToTargetHealthFactor(
    LiquidationLogic.CalculateDebtToTargetHealthFactorParams memory params
  ) external pure returns (uint256) {
    return LiquidationLogic._calculateDebtToTargetHealthFactor(params);
  }

  function calculateDebtToLiquidate(
    LiquidationLogic.CalculateDebtToLiquidateParams memory params
  ) external pure returns (uint256, uint256) {
    return LiquidationLogic._calculateDebtToLiquidate(params);
  }

  function processUserAccountData(
    address user,
    bool refreshConfig
  ) external returns (UserAccountData memory) {
    return _processUserAccountData(user, refreshConfig);
  }
}
