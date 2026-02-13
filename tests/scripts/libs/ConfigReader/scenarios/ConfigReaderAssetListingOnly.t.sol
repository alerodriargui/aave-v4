// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Asset listing only — list new assets on an existing hub, no spoke work.
///
///   Config: config/test-asset-listing-only.json
///   - 0 hubs (already deployed — assets reference "EXISTING_HUB")
///   - 0 spokes (already deployed or not needed yet)
///   - 2 assets (WETH + USDC to list on hub)
///   - 0 spoke registrations (no spoke connections yet)
///   - 0 reserves (reserves configured separately later)
///
///   This represents adding new assets to an existing hub before connecting them
///   to any spoke. Common when:
///   - Governance lists a new asset but spoke registration comes in a separate proposal
///   - Hub admin wants to set up IR strategies before spoke integration
///
///   Tests verify:
///   - Assets parse correctly with zero hubs/spokes/regs/reserves
///   - Asset hub key references external hub ("EXISTING_HUB")
///   - Tokenization defaults apply (WETH inherits enabled=true, USDC opts out)
///   - liquidityFee per-item override works (USDC=500 vs default 1000)
///   - IR data still reads correctly in isolation
contract ConfigReaderAssetListingOnlyTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-asset-listing-only.json');
  }

  function test_assetOnly_counts() public view {
    assertEq(_countHubs(), 0); // hub already exists
    assertEq(_countSpokes(), 0); // no spoke work
    assertEq(_countAssets(), 2); // 2 new assets to list
    assertEq(_countSpokeRegistrations(), 0); // no registrations
    assertEq(_countReserves(), 0); // no reserves
  }

  function test_assetOnly_weth() public view {
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    _assertStr(weth.tokenKey, 'WETH', 'tokenKey');
    _assertStr(weth.hubKey, 'EXISTING_HUB', 'hubKey');
    assertEq(weth.liquidityFee, 10_00); // from defaults
    assertTrue(weth.tokenizeEnabled); // defaults.tokenize.enabled=true
    assertEq(weth.tokenizeAddCap, 1099511627775); // from defaults.tokenize.addCap
  }

  function test_assetOnly_usdc() public view {
    ConfigReader.AssetConfig memory usdc = json.readAsset(1);
    _assertStr(usdc.tokenKey, 'USDC', 'tokenKey');
    _assertStr(usdc.hubKey, 'EXISTING_HUB', 'hubKey');
    assertEq(usdc.liquidityFee, 5_00); // per-item override
    assertFalse(usdc.tokenizeEnabled); // explicit opt-out
  }

  function test_assetOnly_irData() public view {
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    assertEq(weth.irData.optimalUsageRatio, 90_00);
    assertEq(weth.irData.baseVariableBorrowRate, 1_00);
    assertEq(weth.irData.variableRateSlope1, 7_00);
    assertEq(weth.irData.variableRateSlope2, 300_00);
  }

  function test_assetOnly_tokenRegistry() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 2);
    assertEq(json.tokenAddress('WETH'), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    assertEq(json.tokenAddress('USDC'), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  }
}
