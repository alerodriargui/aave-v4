// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Multi-hub deployment — 2 hubs, 2 spokes, cross-hub asset sharing.
///
///   Config: config/test-2hubs-2spokes-cross-hub.json
///   - 2 hubs (PRIME_HUB, CORE_HUB), 2 spokes (PRIME_SPOKE, CORE_SPOKE)
///   - 3 tokens (WETH, USDC, DAI), 4 assets (WETH on both hubs, USDC on PRIME, DAI on CORE)
///   - 4 spoke registrations (2 per spoke), 4 reserves (2 per spoke)
///   - Different liquidation configs per spoke
///   - CORE_SPOKE has custom maxUserReservesLimit=64 (vs default 128)
///   - tokenization disabled globally (defaults.tokenize.enabled=false)
///
///   Tests verify:
///   - Multiple hubs and spokes parsed correctly
///   - Same token (WETH) can appear on different hubs with different IR params
///   - Hub keys, spoke keys, and cross-references resolve correctly
///   - Per-spoke liquidation configs differ
///   - Per-item reserve overrides (maxLiquidationBonus) work alongside defaults
contract ConfigReaderMultiHubTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-2hubs-2spokes-cross-hub.json');
  }

  function test_multiHub_counts() public view {
    assertEq(_countHubs(), 2);
    assertEq(_countSpokes(), 2);
    assertEq(_countAssets(), 4);
    assertEq(_countSpokeRegistrations(), 4);
    assertEq(_countReserves(), 4);
  }

  function test_multiHub_hubKeys() public view {
    _assertStr(json.hubKey(0), 'PRIME_HUB', 'hubKey[0]');
    _assertStr(json.hubKey(1), 'CORE_HUB', 'hubKey[1]');
  }

  function test_multiHub_spokeKeys() public view {
    _assertStr(json.spokeKey(0), 'PRIME_SPOKE', 'spokeKey[0]');
    _assertStr(json.spokeKey(1), 'CORE_SPOKE', 'spokeKey[1]');
  }

  function test_multiHub_wethOnPrimeHub() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    _assertStr(a.tokenKey, 'WETH', 'tokenKey');
    _assertStr(a.hubKey, 'PRIME_HUB', 'hubKey');
    assertEq(a.liquidityFee, 10_00); // from defaults
    assertEq(a.irData.optimalUsageRatio, 90_00);
    assertEq(a.irData.variableRateSlope2, 300_00);
  }

  function test_multiHub_wethOnCoreHub() public view {
    // Same token, different hub, different IR params
    ConfigReader.AssetConfig memory a = json.readAsset(2);
    _assertStr(a.tokenKey, 'WETH', 'tokenKey');
    _assertStr(a.hubKey, 'CORE_HUB', 'hubKey');
    assertEq(a.liquidityFee, 8_00); // per-item override
    assertEq(a.irData.optimalUsageRatio, 80_00);
    assertEq(a.irData.variableRateSlope2, 500_00);
  }

  function test_multiHub_daiOnCoreHub() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(3);
    _assertStr(a.tokenKey, 'DAI', 'tokenKey');
    _assertStr(a.hubKey, 'CORE_HUB', 'hubKey');
    assertEq(a.liquidityFee, 4_00);
    assertEq(a.irData.optimalUsageRatio, 95_00);
  }

  function test_multiHub_spokeRegistrationCrossHub() public view {
    // PRIME_SPOKE registration for WETH on PRIME_HUB
    ConfigReader.SpokeRegistrationConfig memory r0 = json.readSpokeRegistration(0);
    _assertStr(r0.assetKey, 'WETH', 'reg0.assetKey');
    _assertStr(r0.hubKey, 'PRIME_HUB', 'reg0.hubKey');
    _assertStr(r0.spokeKey, 'PRIME_SPOKE', 'reg0.spokeKey');

    // CORE_SPOKE registration for WETH on CORE_HUB
    ConfigReader.SpokeRegistrationConfig memory r2 = json.readSpokeRegistration(2);
    _assertStr(r2.assetKey, 'WETH', 'reg2.assetKey');
    _assertStr(r2.hubKey, 'CORE_HUB', 'reg2.hubKey');
    _assertStr(r2.spokeKey, 'CORE_SPOKE', 'reg2.spokeKey');
    assertEq(r2.addCap, 100);
    assertEq(r2.drawCap, 80);
  }

  function test_multiHub_coreSpokeConfig() public view {
    ConfigReader.SpokeDeployConfig memory s = json.readSpoke(1);
    _assertStr(s.key, 'CORE_SPOKE', 'key');
    assertEq(s.maxUserReservesLimit, 64); // per-spoke override (default is 128)
  }

  function test_multiHub_differentLiquidationConfigs() public view {
    // PRIME_SPOKE: targetHF=1.1, hfForMaxBonus=0.95, bonusFactor=10000
    ISpoke.LiquidationConfig memory lc0 = json.readLiquidationConfig(0);
    assertEq(lc0.targetHealthFactor, 1.1e18);
    assertEq(lc0.healthFactorForMaxBonus, 0.95e18);
    assertEq(lc0.liquidationBonusFactor, 100_00);

    // CORE_SPOKE: targetHF=1.15, hfForMaxBonus=0.9, bonusFactor=8000
    ISpoke.LiquidationConfig memory lc1 = json.readLiquidationConfig(1);
    assertEq(lc1.targetHealthFactor, 1.15e18);
    assertEq(lc1.healthFactorForMaxBonus, 0.9e18);
    assertEq(lc1.liquidationBonusFactor, 80_00);
  }

  function test_multiHub_reserveDefaults() public view {
    // WETH on PRIME_SPOKE — uses default maxLiquidationBonus
    ConfigReader.ReserveConfig memory r0 = json.readReserve(0);
    assertEq(r0.maxLiquidationBonus, 105_00); // from defaults

    // USDC on PRIME_SPOKE — per-item override
    ConfigReader.ReserveConfig memory r1 = json.readReserve(1);
    assertEq(r1.maxLiquidationBonus, 104_00);

    // DAI on CORE_SPOKE — per-item override
    ConfigReader.ReserveConfig memory r3 = json.readReserve(3);
    assertEq(r3.maxLiquidationBonus, 103_00);
  }

  function test_multiHub_threeTokens() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 3);
  }

  function test_multiHub_noTokenization() public view {
    // defaults.tokenize.enabled = false — all assets should inherit
    ConfigReader.AssetConfig memory a0 = json.readAsset(0);
    assertFalse(a0.tokenizeEnabled);
    ConfigReader.AssetConfig memory a3 = json.readAsset(3);
    assertFalse(a3.tokenizeEnabled);
  }
}
