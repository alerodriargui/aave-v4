// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Single hub with 2 spokes — both spokes share the same liquidity pool.
///
///   Config: config/test-hub-2spokes-shared.json
///   - 1 hub (SHARED_HUB), 2 spokes (PRIME_SPOKE, LITE_SPOKE), 2 tokens (WETH, USDC)
///   - 2 assets (both on SHARED_HUB)
///   - 4 spoke registrations (each asset on each spoke)
///   - 4 reserves (each asset on each spoke, with different risk parameters)
///   - LITE_SPOKE: lower maxUserReservesLimit=32, lower caps
///   - USDC on LITE_SPOKE: not borrowable, custom liquidationFee=500
///   - Both spokes inherit same default liquidation config
///   - tokenization disabled globally
///
///   Tests verify:
///   - Two spokes connected to same hub with different parameters
///   - Same asset on different spokes has different reserve configs (caps, borrowable, risk)
///   - maxUserReservesLimit per-spoke override (LITE_SPOKE=32 vs default=128)
///   - Both spokes share same default liquidation config
///   - Not-borrowable reserve (USDC on LITE_SPOKE)
///   - Per-item liquidationFee override
contract ConfigReaderHub2SpokesTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-hub-2spokes-shared.json');
  }

  function test_hub2spokes_counts() public view {
    assertEq(_countHubs(), 1);
    assertEq(_countSpokes(), 2);
    assertEq(_countAssets(), 2);
    assertEq(_countSpokeRegistrations(), 4); // 2 assets × 2 spokes
    assertEq(_countReserves(), 4); // 2 assets × 2 spokes
  }

  function test_hub2spokes_spokeKeys() public view {
    _assertStr(json.spokeKey(0), 'PRIME_SPOKE', 'spokeKey[0]');
    _assertStr(json.spokeKey(1), 'LITE_SPOKE', 'spokeKey[1]');
  }

  function test_hub2spokes_liteSpokeCustomLimit() public view {
    ConfigReader.SpokeDeployConfig memory prime = json.readSpoke(0);
    assertEq(prime.maxUserReservesLimit, 128); // from defaults

    ConfigReader.SpokeDeployConfig memory lite = json.readSpoke(1);
    assertEq(lite.maxUserReservesLimit, 32); // per-spoke override
  }

  function test_hub2spokes_sameAssetDifferentCaps() public view {
    // WETH on PRIME_SPOKE — higher caps
    ConfigReader.SpokeRegistrationConfig memory r0 = json.readSpokeRegistration(0);
    _assertStr(r0.spokeKey, 'PRIME_SPOKE', 'reg0.spokeKey');
    assertEq(r0.addCap, 225);
    assertEq(r0.drawCap, 200);

    // WETH on LITE_SPOKE — lower caps
    ConfigReader.SpokeRegistrationConfig memory r2 = json.readSpokeRegistration(2);
    _assertStr(r2.spokeKey, 'LITE_SPOKE', 'reg2.spokeKey');
    assertEq(r2.addCap, 50);
    assertEq(r2.drawCap, 40);
  }

  function test_hub2spokes_usdcNotBorrowableOnLite() public view {
    // USDC on PRIME_SPOKE — borrowable
    ConfigReader.ReserveConfig memory prime = json.readReserve(1);
    _assertStr(prime.spokeKey, 'PRIME_SPOKE', 'prime.spokeKey');
    assertTrue(prime.borrowable);

    // USDC on LITE_SPOKE — not borrowable
    ConfigReader.ReserveConfig memory lite = json.readReserve(3);
    _assertStr(lite.spokeKey, 'LITE_SPOKE', 'lite.spokeKey');
    assertFalse(lite.borrowable);
  }

  function test_hub2spokes_customLiquidationFee() public view {
    // USDC on LITE_SPOKE: custom liquidationFee=500
    ConfigReader.ReserveConfig memory r = json.readReserve(3);
    assertEq(r.liquidationFee, 5_00); // per-item override (default is 1000)
  }

  function test_hub2spokes_sharedLiquidationConfig() public view {
    // Both spokes inherit same default liquidation config
    ISpoke.LiquidationConfig memory lc0 = json.readLiquidationConfig(0);
    ISpoke.LiquidationConfig memory lc1 = json.readLiquidationConfig(1);

    assertEq(lc0.targetHealthFactor, lc1.targetHealthFactor);
    assertEq(lc0.healthFactorForMaxBonus, lc1.healthFactorForMaxBonus);
    assertEq(lc0.liquidationBonusFactor, lc1.liquidationBonusFactor);
  }

  function test_hub2spokes_allRegsPointToSameHub() public view {
    for (uint i; i < 4; i++) {
      ConfigReader.SpokeRegistrationConfig memory r = json.readSpokeRegistration(i);
      _assertStr(r.hubKey, 'SHARED_HUB', string.concat('reg', vm.toString(i), '.hubKey'));
    }
  }

  function test_hub2spokes_noTokenization() public view {
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    assertFalse(weth.tokenizeEnabled);
    ConfigReader.AssetConfig memory usdc = json.readAsset(1);
    assertFalse(usdc.tokenizeEnabled);
  }
}
