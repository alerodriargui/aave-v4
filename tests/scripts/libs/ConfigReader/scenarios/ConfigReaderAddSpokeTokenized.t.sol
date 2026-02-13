// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Deploy a tokenized spoke and connect to an existing hub, mixed tokenization.
///
///   Config: config/test/test-add-spoke-with-tokenization.json
///   - 0 hubs (EXISTING_HUB already deployed)
///   - 1 spoke (TOKENIZED_SPOKE to deploy)
///   - 2 assets (WETH + USDC to list on existing hub — may be new listings or already exist)
///   - 2 spoke registrations (connect both assets to TOKENIZED_SPOKE)
///   - 2 reserves (WETH not borrowable, USDC borrowable)
///   - defaults.tokenize.enabled = true, addCap = 1099511627775
///   - WETH: explicit tokenize.enabled=true, addCap=500 (per-item override)
///   - USDC: explicit tokenize.enabled=false (opt-out despite default=true)
///
///   This represents adding a tokenized spoke where some assets get tokenized
///   (ERC-4626 vault shares) and others don't.
///
///   Tests verify:
///   - Mixed tokenization: WETH tokenized with custom addCap, USDC not tokenized
///   - Assets have hub key pointing to EXISTING_HUB
///   - WETH reserve is not borrowable (supply-only collateral)
///   - Default tokenize.addCap inherited by assets without explicit override
///   - Per-item liquidityFee override on USDC
contract ConfigReaderAddSpokeTokenizedTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-add-spoke-with-tokenization.json');
  }

  function test_addSpokeTokenized_counts() public view {
    assertEq(_countHubs(), 0);
    assertEq(_countSpokes(), 1);
    assertEq(_countAssets(), 2);
    assertEq(_countSpokeRegistrations(), 2);
    assertEq(_countReserves(), 2);
  }

  function test_addSpokeTokenized_wethTokenized() public view {
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    _assertStr(weth.tokenKey, 'WETH', 'tokenKey');
    _assertStr(weth.hubKey, 'EXISTING_HUB', 'hubKey');
    assertTrue(weth.tokenizeEnabled);
    assertEq(weth.tokenizeAddCap, 500); // per-item override
  }

  function test_addSpokeTokenized_usdcNotTokenized() public view {
    ConfigReader.AssetConfig memory usdc = json.readAsset(1);
    _assertStr(usdc.tokenKey, 'USDC', 'tokenKey');
    assertFalse(usdc.tokenizeEnabled); // explicit opt-out
    assertEq(usdc.liquidityFee, 5_00); // per-item override
  }

  function test_addSpokeTokenized_wethNotBorrowable() public view {
    ConfigReader.ReserveConfig memory weth = json.readReserve(0);
    _assertStr(weth.assetKey, 'WETH', 'assetKey');
    assertFalse(weth.borrowable); // supply-only collateral
    assertEq(weth.collateralFactor, 80_00);
  }

  function test_addSpokeTokenized_usdcBorrowable() public view {
    ConfigReader.ReserveConfig memory usdc = json.readReserve(1);
    _assertStr(usdc.assetKey, 'USDC', 'assetKey');
    assertTrue(usdc.borrowable);
    assertEq(usdc.collateralRisk, 30_00);
  }

  function test_addSpokeTokenized_spokeRegistrations() public view {
    ConfigReader.SpokeRegistrationConfig memory r0 = json.readSpokeRegistration(0);
    _assertStr(r0.spokeKey, 'TOKENIZED_SPOKE', 'reg0.spokeKey');
    assertEq(r0.addCap, 100);

    ConfigReader.SpokeRegistrationConfig memory r1 = json.readSpokeRegistration(1);
    _assertStr(r1.spokeKey, 'TOKENIZED_SPOKE', 'reg1.spokeKey');
    assertEq(r1.addCap, 200000);
  }

  function test_addSpokeTokenized_liquidationConfig() public view {
    ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(0);
    assertEq(lc.targetHealthFactor, 1.1e18);
    assertEq(lc.healthFactorForMaxBonus, 0.95e18);
  }
}
