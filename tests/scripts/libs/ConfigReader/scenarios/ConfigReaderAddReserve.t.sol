// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Add a new reserve to an already-deployed hub/spoke/asset setup.
///
///   Config: config/test/test-add-reserve-to-existing.json
///   - 0 hubs, 0 spokes, 0 assets (all already deployed)
///   - 1 spoke registration (DAI on EXISTING_HUB → EXISTING_SPOKE)
///   - 1 reserve (DAI on EXISTING_SPOKE with custom liquidationFee=500, maxLiquidationBonus=10300)
///
///   This is the most incremental config possible — hub, spoke, and other assets
///   already exist. We're just adding DAI as a new spoke registration + reserve.
///   Common for governance proposals that add a single new collateral type.
///
///   Tests verify:
///   - Zero hubs/spokes/assets parse correctly
///   - Single spoke registration with custom caps
///   - Single reserve with per-item overrides on liquidationFee and maxLiquidationBonus
///   - References to external keys (EXISTING_HUB, EXISTING_SPOKE) parse correctly
contract ConfigReaderAddReserveTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-add-reserve-to-existing.json');
  }

  function test_addReserve_counts() public view {
    assertEq(_countHubs(), 0);
    assertEq(_countSpokes(), 0);
    assertEq(_countAssets(), 0);
    assertEq(_countSpokeRegistrations(), 1);
    assertEq(_countReserves(), 1);
  }

  function test_addReserve_spokeRegistration() public view {
    ConfigReader.SpokeRegistrationConfig memory reg = json.readSpokeRegistration(0);
    _assertStr(reg.assetKey, 'DAI', 'assetKey');
    _assertStr(reg.hubKey, 'EXISTING_HUB', 'hubKey');
    _assertStr(reg.spokeKey, 'EXISTING_SPOKE', 'spokeKey');
    assertEq(reg.addCap, 2000000);
    assertEq(reg.drawCap, 1500000);
    assertTrue(reg.active); // from defaults
    assertFalse(reg.halted); // from defaults
  }

  function test_addReserve_reserveOverrides() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(0);
    _assertStr(r.assetKey, 'DAI', 'assetKey');
    assertTrue(r.borrowable);
    assertEq(r.collateralRisk, 20_00);
    assertEq(r.collateralFactor, 90_00);
    assertEq(r.maxLiquidationBonus, 103_00); // per-item override
    assertEq(r.liquidationFee, 5_00); // per-item override (default is 1000)
    assertTrue(r.receiveSharesEnabled); // from defaults
    assertFalse(r.frozen); // from defaults
  }

  function test_addReserve_twoTokens() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 2); // WETH + DAI in registry
  }
}
