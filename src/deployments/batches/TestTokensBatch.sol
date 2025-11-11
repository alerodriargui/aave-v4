// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/types/BatchReports.sol';

import {WETHDeployProcedure} from 'src/deployments/procedures/deploy/WETHDeployProcedure.sol';
import {TestnetERC20DeployProcedure} from 'src/deployments/procedures/deploy/TestnetERC20DeployProcedure.sol';

contract TestTokensBatch is WETHDeployProcedure, TestnetERC20DeployProcedure {
  struct TestTokensInput {
    string name;
    string symbol;
    uint8 decimals;
  }

  BatchReports.TestTokensBatchReport internal _report;

  constructor(TestTokensInput[] memory inputs_) {
    _report.tokenAddresses = new address[](inputs_.length);
    _report.wethAddress = _deployWETH();

    for (uint256 i; i < inputs_.length; i++) {
      TestTokensInput memory input = inputs_[i];
      address tokenAddress = _deployTestnetERC20(input.name, input.symbol, input.decimals);
      _report.tokenAddresses[i] = tokenAddress;
    }
  }

  function getReport() external view returns (BatchReports.TestTokensBatchReport memory) {
    return _report;
  }
}
