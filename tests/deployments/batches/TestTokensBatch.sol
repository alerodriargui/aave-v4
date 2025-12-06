// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

import {WETHDeployProcedure} from 'src/deployments/procedures/deploy/WETHDeployProcedure.sol';
import {TestnetERC20DeployProcedure} from 'src/deployments/procedures/deploy/TestnetERC20DeployProcedure.sol';

contract TestTokensBatch is WETHDeployProcedure, TestnetERC20DeployProcedure {
  BatchReports.TestTokensBatchReport internal _report;

  constructor(ConfigData.TestTokenInput[] memory inputs_) {
    _report.tokenAddresses = new address[](inputs_.length);
    _report.wethAddress = _deployWETH();

    for (uint256 i; i < inputs_.length; i++) {
      ConfigData.TestTokenInput memory input = inputs_[i];
      address tokenAddress = _deployTestnetERC20(input.name, input.symbol, input.decimals);
      _report.tokenAddresses[i] = tokenAddress;
    }
  }

  function getReport() external view returns (BatchReports.TestTokensBatchReport memory) {
    return _report;
  }
}
