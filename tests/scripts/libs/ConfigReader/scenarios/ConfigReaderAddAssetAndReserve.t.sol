// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Combined asset listing + spoke registration + reserve in one config.
///
///   Config: config/test/test-add-asset-and-reserve.json
///   - 0 hubs, 0 spokes (EXISTING_HUB + EXISTING_SPOKE already deployed)
///   - 1 asset (LINK on EXISTING_HUB with custom liquidityFee=800)
///   - 1 spoke registration (LINK on EXISTING_HUB → EXISTING_SPOKE)
///   - 1 reserve (LINK on EXISTING_SPOKE with custom overrides)
///   - tokenization disabled globally
///
///   This represents the complete "add a new collateral type end-to-end" governance
///   proposal: list the asset on hub, register the spoke, configure the reserve.
///   All three steps in a single config file, no new contracts to deploy.
///
///   Tests verify:
///   - All three sections (asset, spokeRegistration, reserve) present with zero hubs/spokes
///   - Per-item liquidityFee override on asset (800 vs default 1000)
///   - Per-item maxLiquidationBonus and liquidationFee overrides on reserve
///   - Spoke registration caps parsed correctly
///   - All reference same token (LINK) and same external keys
contract ConfigReaderAddAssetAndReserveTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-add-asset-and-reserve.json');
  }

  function test_addAssetAndReserve_counts() public view {
    assertEq(_countHubs(), 0);
    assertEq(_countSpokes(), 0);
    assertEq(_countAssets(), 1);
    assertEq(_countSpokeRegistrations(), 1);
    assertEq(_countReserves(), 1);
  }

  function test_addAssetAndReserve_asset() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    _assertStr(a.tokenKey, 'LINK', 'tokenKey');
    _assertStr(a.hubKey, 'EXISTING_HUB', 'hubKey');
    assertEq(a.liquidityFee, 8_00); // per-item override
    assertFalse(a.tokenizeEnabled);
  }

  function test_addAssetAndReserve_spokeRegistration() public view {
    ConfigReader.SpokeRegistrationConfig memory reg = json.readSpokeRegistration(0);
    _assertStr(reg.assetKey, 'LINK', 'assetKey');
    _assertStr(reg.hubKey, 'EXISTING_HUB', 'hubKey');
    _assertStr(reg.spokeKey, 'EXISTING_SPOKE', 'spokeKey');
    assertEq(reg.addCap, 5000);
    assertEq(reg.drawCap, 3000);
    assertTrue(reg.active); // from defaults
    assertFalse(reg.halted); // from defaults
  }

  function test_addAssetAndReserve_reserve() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(0);
    _assertStr(r.assetKey, 'LINK', 'assetKey');
    _assertStr(r.spokeKey, 'EXISTING_SPOKE', 'spokeKey');
    assertTrue(r.borrowable);
    assertEq(r.collateralRisk, 65_00);
    assertEq(r.collateralFactor, 72_00);
    assertEq(r.maxLiquidationBonus, 106_00); // per-item override
    assertEq(r.liquidationFee, 8_00); // per-item override
    assertTrue(r.receiveSharesEnabled); // from defaults
  }

  function test_addAssetAndReserve_irData() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    assertEq(a.irData.optimalUsageRatio, 45_00);
    assertEq(a.irData.variableRateSlope1, 7_00);
    assertEq(a.irData.variableRateSlope2, 300_00);
  }

  function test_addAssetAndReserve_singleToken() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 1);
    assertEq(json.tokenAddress('LINK'), 0x514910771AF9Ca656af840dff83E8264EcF986CA);
  }
}
