// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

library TestTypes {
  struct TokenList {
    WETH9 weth;
    TestnetERC20 usdx;
    TestnetERC20 dai;
    TestnetERC20 wbtc;
    TestnetERC20 usdy;
    TestnetERC20 usdz;
  }

  struct SpokeReserveId {
    address spoke;
    uint256 reserveId;
  }

  struct TestTokensBatchReport {
    address wethAddress;
    address[] tokenAddresses;
  }

  struct TestTokenInput {
    string name;
    string symbol;
    uint8 decimals;
  }

  struct TestHubReport {
    address hubAddress;
    address irStrategyAddress;
    address treasurySpokeAddress;
  }

  struct TestSpokeReport {
    address spokeAddress;
    address aaveOracleAddress;
  }

  struct TestEnvReport {
    address accessManagerAddress;
    TestHubReport[] hubReports;
    TestSpokeReport[] spokeReports;
  }

  struct TestTokensReport {
    address wethAddress;
    address[] testTokenAddresses;
  }
}
