// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Mixed tokenization — some assets enable tokenization, some disable, some inherit default.
///
///   Config: config/test-hub-spoke-mixed-tokenization.json
///   - 1 hub (PRIME_HUB), 1 spoke (PRIME_SPOKE), 3 tokens (WETH, USDC, WBTC)
///   - defaults.tokenize.enabled = true, defaults.tokenize.addCap = 1099511627775
///   - WETH: explicit tokenize.enabled=true, addCap=500 (per-item override)
///   - USDC: explicit tokenize.enabled=false (opt-out)
///   - WBTC: no tokenize field → inherits default (enabled=true, addCap from defaults)
///
///   Tests verify:
///   - Per-item tokenize override takes precedence over defaults
///   - Explicit opt-out disables tokenization
///   - Missing tokenize field inherits from defaults section
///   - IR data, reserve config, and spoke registration read correctly for 3-asset setup
contract ConfigReaderTokenizationTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-hub-spoke-mixed-tokenization.json');
  }

  function test_tokenization_counts() public view {
    assertEq(_countHubs(), 1);
    assertEq(_countSpokes(), 1);
    assertEq(_countAssets(), 3);
    assertEq(_countSpokeRegistrations(), 3);
    assertEq(_countReserves(), 3);
  }

  function test_tokenization_threeTokens() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 3);
  }

  function test_tokenization_weth_explicitEnable() public view {
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    _assertStr(weth.tokenKey, 'WETH', 'tokenKey');
    assertTrue(weth.tokenizeEnabled);
    assertEq(weth.tokenizeAddCap, 500); // explicit per-item addCap
  }

  function test_tokenization_usdc_explicitDisable() public view {
    ConfigReader.AssetConfig memory usdc = json.readAsset(1);
    _assertStr(usdc.tokenKey, 'USDC', 'tokenKey');
    assertFalse(usdc.tokenizeEnabled); // explicitly disabled
  }

  function test_tokenization_wbtc_inheritDefault() public view {
    // WBTC has no tokenize field → inherits default (enabled=true, addCap from defaults)
    ConfigReader.AssetConfig memory wbtc = json.readAsset(2);
    _assertStr(wbtc.tokenKey, 'WBTC', 'tokenKey');
    assertTrue(wbtc.tokenizeEnabled);
    assertEq(wbtc.tokenizeAddCap, 1099511627775); // from defaults.tokenize.addCap
  }

  function test_tokenization_wbtcReserve() public view {
    ConfigReader.ReserveConfig memory wbtc = json.readReserve(2);
    _assertStr(wbtc.assetKey, 'WBTC', 'assetKey');
    assertEq(wbtc.collateralRisk, 60_00);
    assertEq(wbtc.collateralFactor, 75_00);
    assertEq(wbtc.maxLiquidationBonus, 105_00); // from defaults
  }

  function test_tokenization_wbtcIrData() public view {
    ConfigReader.AssetConfig memory wbtc = json.readAsset(2);
    assertEq(wbtc.irData.optimalUsageRatio, 45_00);
    assertEq(wbtc.irData.baseVariableBorrowRate, 0);
    assertEq(wbtc.irData.variableRateSlope1, 4_00);
    assertEq(wbtc.irData.variableRateSlope2, 800_00);
  }

  function test_tokenization_wbtcSpokeRegistration() public view {
    ConfigReader.SpokeRegistrationConfig memory reg = json.readSpokeRegistration(2);
    _assertStr(reg.assetKey, 'WBTC', 'assetKey');
    assertEq(reg.addCap, 50);
    assertEq(reg.drawCap, 40);
  }
}
