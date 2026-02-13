// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Deploy a new spoke and connect it to an existing hub with already-listed assets.
///
///   Config: config/test/test-add-spoke-to-existing-hub.json
///   - 0 hubs (EXISTING_HUB already deployed)
///   - 1 spoke (NEW_SPOKE to deploy, maxUserReservesLimit=64)
///   - 0 assets (WETH + USDC already listed on hub)
///   - 2 spoke registrations (connect both assets to NEW_SPOKE)
///   - 2 reserves (WETH + USDC on NEW_SPOKE)
///   - Custom per-spoke liquidation config (targetHF=1.15, hfForMaxBonus=0.9, bonusFactor=8000)
///   - tokenization disabled globally
///
///   This represents expanding to a new spoke market — the hub and assets exist,
///   we're deploying a fresh spoke, registering the hub's assets, and configuring reserves.
///
///   Tests verify:
///   - New spoke with custom liquidation config different from defaults
///   - Spoke registrations referencing external hub key
///   - Custom maxUserReservesLimit on new spoke
///   - USDC reserve has per-item maxLiquidationBonus override
///   - No assets or hubs to deploy (zero counts)
contract ConfigReaderAddSpokeTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-add-spoke-to-existing-hub.json');
  }

  function test_addSpoke_counts() public view {
    assertEq(_countHubs(), 0);
    assertEq(_countSpokes(), 1);
    assertEq(_countAssets(), 0);
    assertEq(_countSpokeRegistrations(), 2);
    assertEq(_countReserves(), 2);
  }

  function test_addSpoke_spokeConfig() public view {
    ConfigReader.SpokeDeployConfig memory s = json.readSpoke(0);
    _assertStr(s.key, 'NEW_SPOKE', 'key');
    assertEq(s.maxUserReservesLimit, 64);
    assertEq(s.oracleDecimals, 8);
  }

  function test_addSpoke_customLiquidationConfig() public view {
    ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(0);
    assertEq(lc.targetHealthFactor, 1.15e18); // different from default 1.1
    assertEq(lc.healthFactorForMaxBonus, 0.9e18); // different from default 0.95
    assertEq(lc.liquidationBonusFactor, 80_00); // different from default 10000
  }

  function test_addSpoke_spokeRegistrations() public view {
    ConfigReader.SpokeRegistrationConfig memory r0 = json.readSpokeRegistration(0);
    _assertStr(r0.assetKey, 'WETH', 'reg0.assetKey');
    _assertStr(r0.hubKey, 'EXISTING_HUB', 'reg0.hubKey');
    _assertStr(r0.spokeKey, 'NEW_SPOKE', 'reg0.spokeKey');
    assertEq(r0.addCap, 300);

    ConfigReader.SpokeRegistrationConfig memory r1 = json.readSpokeRegistration(1);
    _assertStr(r1.assetKey, 'USDC', 'reg1.assetKey');
    assertEq(r1.addCap, 750000);
  }

  function test_addSpoke_reserveWithOverride() public view {
    ConfigReader.ReserveConfig memory weth = json.readReserve(0);
    assertEq(weth.maxLiquidationBonus, 105_00); // from defaults

    ConfigReader.ReserveConfig memory usdc = json.readReserve(1);
    assertEq(usdc.maxLiquidationBonus, 103_50); // per-item override
    assertEq(usdc.collateralFactor, 88_00);
  }
}
