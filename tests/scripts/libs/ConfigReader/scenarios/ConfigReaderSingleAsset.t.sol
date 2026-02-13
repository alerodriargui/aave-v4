// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Minimal single-asset deployment — the smallest valid config.
///
///   Config: config/test-single-asset.json
///   - 1 hub (SINGLE_HUB), 1 spoke (SINGLE_SPOKE), 1 token (WETH)
///   - All admin addresses = address(1) (single deployer)
///   - maxUserReservesLimit = 32 (low limit)
///   - No defaults.spoke section → spoke config is inline
///   - tokenization disabled (defaults.tokenize.enabled=false)
///   - Minimal defaults (no spoke defaults, no liquidation config defaults)
///
///   Tests verify:
///   - Single hub/spoke/asset/registration/reserve each parse correctly
///   - All admin addresses share the same address
///   - Custom maxUserReservesLimit override
///   - Missing defaults sections don't cause parse errors
///   - Single-item arrays return correct element at index 0
contract ConfigReaderSingleAssetTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-single-asset.json');
  }

  function test_singleAsset_counts() public view {
    assertEq(_countHubs(), 1);
    assertEq(_countSpokes(), 1);
    assertEq(_countAssets(), 1);
    assertEq(_countSpokeRegistrations(), 1);
    assertEq(_countReserves(), 1);
  }

  function test_singleAsset_singleToken() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 1);
  }

  function test_singleAsset_infrastructure() public view {
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();
    // All admins share the same address
    assertEq(infra.accessManagerAdmin, address(1));
    assertEq(infra.hubConfiguratorAdmin, address(1));
    assertEq(infra.spokeConfiguratorAdmin, address(1));
    assertEq(infra.treasurySpokeOwner, address(1));
    assertEq(infra.spokeProxyAdminOwner, address(1));
    _assertStr(infra.salt, 'minimal-v1', 'salt');
  }

  function test_singleAsset_hubKey() public view {
    _assertStr(json.hubKey(0), 'SINGLE_HUB', 'hubKey[0]');
  }

  function test_singleAsset_spokeConfig() public view {
    ConfigReader.SpokeDeployConfig memory s = json.readSpoke(0);
    _assertStr(s.key, 'SINGLE_SPOKE', 'key');
    assertEq(s.maxUserReservesLimit, 32); // custom low limit
    assertEq(s.oracleDecimals, 8);
  }

  function test_singleAsset_assetConfig() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    _assertStr(a.tokenKey, 'WETH', 'tokenKey');
    _assertStr(a.hubKey, 'SINGLE_HUB', 'hubKey');
    assertEq(a.liquidityFee, 10_00); // from defaults
    assertFalse(a.tokenizeEnabled); // defaults.tokenize.enabled=false
  }

  function test_singleAsset_irData() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    assertEq(a.irData.optimalUsageRatio, 90_00);
    assertEq(a.irData.baseVariableBorrowRate, 1_00);
    assertEq(a.irData.variableRateSlope1, 7_00);
    assertEq(a.irData.variableRateSlope2, 300_00);
  }

  function test_singleAsset_spokeRegistration() public view {
    ConfigReader.SpokeRegistrationConfig memory r = json.readSpokeRegistration(0);
    _assertStr(r.assetKey, 'WETH', 'assetKey');
    _assertStr(r.hubKey, 'SINGLE_HUB', 'hubKey');
    _assertStr(r.spokeKey, 'SINGLE_SPOKE', 'spokeKey');
    assertEq(r.addCap, 1000);
    assertEq(r.drawCap, 800);
  }

  function test_singleAsset_reserve() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(0);
    _assertStr(r.spokeKey, 'SINGLE_SPOKE', 'spokeKey');
    _assertStr(r.assetKey, 'WETH', 'assetKey');
    assertTrue(r.borrowable);
    assertEq(r.collateralRisk, 50_00);
    assertEq(r.collateralFactor, 80_00);
    assertEq(r.maxLiquidationBonus, 105_00); // from defaults
  }

  function test_singleAsset_liquidationConfig() public view {
    ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(0);
    assertEq(lc.targetHealthFactor, 1.1e18);
    assertEq(lc.healthFactorForMaxBonus, 0.95e18);
    assertEq(lc.liquidationBonusFactor, 100_00);
  }
}
