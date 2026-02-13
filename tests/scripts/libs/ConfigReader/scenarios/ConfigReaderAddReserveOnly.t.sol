// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Add a reserve on an existing spoke — no hub/asset/spoke-reg work.
///
///   Config: config/test/test-add-reserve-only.json
///   - 0 hubs, 0 spokes, 0 assets, 0 spoke registrations
///   - 1 reserve (WETH on EXISTING_SPOKE, referencing EXISTING_HUB)
///
///   This is the absolute minimal spoke-side config: the hub has the asset listed,
///   the spoke registration already exists, we're just adding a reserve to configure
///   the spoke's lending parameters. Common when reserve parameters need a separate
///   governance proposal from the spoke registration.
///
///   Tests verify:
///   - Single reserve with all other sections empty
///   - Default values applied (receiveSharesEnabled, maxLiquidationBonus, liquidationFee)
///   - Reserve references external keys for spoke and hub
///   - collateralFactor is a per-item value (8200)
contract ConfigReaderAddReserveOnlyTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-add-reserve-only.json');
  }

  function test_addReserveOnly_counts() public view {
    assertEq(_countHubs(), 0);
    assertEq(_countSpokes(), 0);
    assertEq(_countAssets(), 0);
    assertEq(_countSpokeRegistrations(), 0);
    assertEq(_countReserves(), 1);
  }

  function test_addReserveOnly_reserve() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(0);
    _assertStr(r.spokeKey, 'EXISTING_SPOKE', 'spokeKey');
    _assertStr(r.hubKey, 'EXISTING_HUB', 'hubKey');
    _assertStr(r.assetKey, 'WETH', 'assetKey');
    assertTrue(r.borrowable);
    assertEq(r.collateralRisk, 50_00);
    assertEq(r.collateralFactor, 82_00);
  }

  function test_addReserveOnly_defaults() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(0);
    assertTrue(r.receiveSharesEnabled); // from defaults
    assertFalse(r.frozen); // from defaults
    assertFalse(r.paused); // from defaults
    assertEq(r.maxLiquidationBonus, 105_00); // from defaults
    assertEq(r.liquidationFee, 10_00); // from defaults
  }
}
