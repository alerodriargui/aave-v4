// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Spoke registration only — add a new spoke to an existing hub with already-listed assets.
///
///   Config: config/test-spoke-reg-only.json
///   - 0 hubs (already deployed — hub referenced as "EXISTING_HUB")
///   - 1 spoke (NEW_SPOKE) to deploy
///   - 0 assets (WETH+USDC already listed on the hub)
///   - 2 spoke registrations (connect existing assets to new spoke)
///   - 2 reserves (configure WETH+USDC on the new spoke)
///
///   This represents the common post-deploy operation of expanding to a new spoke:
///   the hub and its assets already exist, we just need to:
///   1. Deploy the new spoke
///   2. Register existing hub assets on the new spoke
///   3. Configure reserves on the new spoke
///
///   Tests verify:
///   - Zero hubs and zero assets arrays parse correctly
///   - Spoke registrations reference an external hub key ("EXISTING_HUB")
///   - Reserves and spoke config read independently of hub/asset sections
///   - Custom maxUserReservesLimit=64 on the new spoke
///   - Per-item maxLiquidationBonus override on USDC reserve
contract ConfigReaderSpokeRegistrationOnlyTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-spoke-reg-only.json');
  }

  function test_spokeRegistrationOnly_counts() public view {
    assertEq(_countHubs(), 0); // no new hubs to deploy
    assertEq(_countSpokes(), 1); // one new spoke
    assertEq(_countAssets(), 0); // assets already listed
    assertEq(_countSpokeRegistrations(), 2); // register 2 existing assets on new spoke
    assertEq(_countReserves(), 2); // configure 2 reserves
  }

  function test_spokeRegistrationOnly_spokeConfig() public view {
    ConfigReader.SpokeDeployConfig memory s = json.readSpoke(0);
    _assertStr(s.key, 'NEW_SPOKE', 'key');
    assertEq(s.maxUserReservesLimit, 64);
    assertEq(s.oracleDecimals, 8);
  }

  function test_spokeRegistrationOnly_regsReferenceExistingHub() public view {
    ConfigReader.SpokeRegistrationConfig memory r0 = json.readSpokeRegistration(0);
    _assertStr(r0.assetKey, 'WETH', 'reg0.assetKey');
    _assertStr(r0.hubKey, 'EXISTING_HUB', 'reg0.hubKey');
    _assertStr(r0.spokeKey, 'NEW_SPOKE', 'reg0.spokeKey');
    assertEq(r0.addCap, 500);
    assertEq(r0.drawCap, 400);

    ConfigReader.SpokeRegistrationConfig memory r1 = json.readSpokeRegistration(1);
    _assertStr(r1.assetKey, 'USDC', 'reg1.assetKey');
    _assertStr(r1.hubKey, 'EXISTING_HUB', 'reg1.hubKey');
  }

  function test_spokeRegistrationOnly_reserves() public view {
    ConfigReader.ReserveConfig memory weth = json.readReserve(0);
    _assertStr(weth.assetKey, 'WETH', 'weth.assetKey');
    assertEq(weth.maxLiquidationBonus, 105_00); // from defaults

    ConfigReader.ReserveConfig memory usdc = json.readReserve(1);
    _assertStr(usdc.assetKey, 'USDC', 'usdc.assetKey');
    assertEq(usdc.maxLiquidationBonus, 104_00); // per-item override
    assertEq(usdc.collateralFactor, 85_00);
  }

  function test_spokeRegistrationOnly_liquidationConfig() public view {
    ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(0);
    assertEq(lc.targetHealthFactor, 1.1e18);
    assertEq(lc.healthFactorForMaxBonus, 0.95e18);
    assertEq(lc.liquidationBonusFactor, 100_00);
  }

  function test_spokeRegistrationOnly_twoTokens() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 2);
  }
}
