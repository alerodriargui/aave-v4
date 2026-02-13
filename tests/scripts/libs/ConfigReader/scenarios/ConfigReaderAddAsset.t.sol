// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: List a new asset on an existing hub — no spoke/reserve work.
///
///   Config: config/test/test-add-asset-to-existing-hub.json
///   - 0 hubs, 0 spokes (EXISTING_HUB already deployed)
///   - 1 asset (WBTC to list on EXISTING_HUB)
///   - 0 spoke registrations, 0 reserves
///   - tokenization disabled globally
///
///   This represents the minimal "list a new collateral type on an existing hub"
///   step, done before spoke registration and reserve configuration.
///
///   Tests verify:
///   - Single asset with zero everything else parses correctly
///   - Asset references external hub key
///   - IR data fields parsed
///   - Token registry has just the one token
///   - liquidityFee from defaults applied
contract ConfigReaderAddAssetTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-add-asset-to-existing-hub.json');
  }

  function test_addAsset_counts() public view {
    assertEq(_countHubs(), 0);
    assertEq(_countSpokes(), 0);
    assertEq(_countAssets(), 1);
    assertEq(_countSpokeRegistrations(), 0);
    assertEq(_countReserves(), 0);
  }

  function test_addAsset_wbtcConfig() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    _assertStr(a.tokenKey, 'WBTC', 'tokenKey');
    _assertStr(a.hubKey, 'EXISTING_HUB', 'hubKey');
    assertEq(a.liquidityFee, 10_00); // from defaults
    assertFalse(a.tokenizeEnabled);
  }

  function test_addAsset_irData() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    assertEq(a.irData.optimalUsageRatio, 45_00);
    assertEq(a.irData.baseVariableBorrowRate, 0);
    assertEq(a.irData.variableRateSlope1, 4_00);
    assertEq(a.irData.variableRateSlope2, 800_00);
  }

  function test_addAsset_singleToken() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 1);
    assertEq(json.tokenAddress('WBTC'), 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
  }
}
