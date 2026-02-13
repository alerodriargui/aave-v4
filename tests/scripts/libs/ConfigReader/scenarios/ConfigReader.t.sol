// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Standard 2-asset deployment — full coverage of all ConfigReader functions.
///
///   Config: config/test-hub-spoke-2assets.json
///   - 1 hub (TEST_HUB), 1 spoke (TEST_SPOKE), 2 tokens (WETH, USDC)
///   - defaults.tokenize.enabled = true → WETH inherits (tokenized)
///   - USDC: explicit tokenize.enabled = false (opt-out)
///   - defaults.asset.liquidityFee = 1000, USDC overrides to 500
///   - defaults.reserve.maxLiquidationBonus = 10500, USDC overrides to 10400
///   - Infrastructure: 7 distinct admin addresses + nativeWrapper + gatewayOwner
///
///   Tests verify:
///   - All reader functions return correct typed values
///   - Infrastructure parsing (all fields including optionals)
///   - Token registry (keys, addresses, price feeds)
///   - 3-level default resolution (per-item → defaults → hardcoded)
///   - Existence counting via iterative checks
///   - String key lookups (hub, spoke)
///   - trimEnd utility
contract ConfigReaderTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-hub-spoke-2assets.json');
  }

  // ==================== Infrastructure ====================

  function test_readInfrastructure() public view {
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();
    assertEq(infra.accessManagerAdmin, address(1));
    assertEq(infra.hubConfiguratorAdmin, address(2));
    assertEq(infra.spokeConfiguratorAdmin, address(3));
    assertEq(infra.treasurySpokeOwner, address(4));
    assertEq(infra.spokeProxyAdminOwner, address(5));
    assertEq(infra.gatewayOwner, address(6));
    assertEq(infra.nativeWrapper, address(7));
    _assertStr(infra.salt, 'test-v1', 'salt');
  }

  // ==================== Token Registry ====================

  function test_tokenKeys() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 2);
  }

  function test_tokenAddress() public view {
    assertEq(json.tokenAddress('WETH'), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    assertEq(json.tokenAddress('USDC'), 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
  }

  function test_tokenPriceFeed() public view {
    assertEq(json.tokenPriceFeed('WETH'), 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
  }

  // ==================== Existence Counts ====================

  function test_counts() public view {
    assertEq(_countHubs(), 1);
    assertEq(_countSpokes(), 1);
    assertEq(_countAssets(), 2);
    assertEq(_countSpokeRegistrations(), 2);
    assertEq(_countReserves(), 2);
  }

  // ==================== Hub/Spoke Keys ====================

  function test_hubKey() public view {
    _assertStr(json.hubKey(0), 'TEST_HUB', 'hubKey[0]');
  }

  function test_spokeKey() public view {
    _assertStr(json.spokeKey(0), 'TEST_SPOKE', 'spokeKey[0]');
  }

  // ==================== Asset Reader ====================

  function test_readAsset_weth() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(0);
    _assertStr(a.tokenKey, 'WETH', 'tokenKey');
    _assertStr(a.hubKey, 'TEST_HUB', 'hubKey');
    assertEq(a.liquidityFee, 10_00); // from defaults
    assertEq(a.irData.optimalUsageRatio, 90_00);
    assertEq(a.irData.baseVariableBorrowRate, 5_00);
    assertEq(a.irData.variableRateSlope1, 5_00);
    assertEq(a.irData.variableRateSlope2, 5_00);
    assertTrue(a.tokenizeEnabled);
  }

  function test_readAsset_usdc() public view {
    ConfigReader.AssetConfig memory a = json.readAsset(1);
    _assertStr(a.tokenKey, 'USDC', 'tokenKey');
    assertEq(a.liquidityFee, 5_00); // per-item override
    assertFalse(a.tokenizeEnabled);
  }

  // ==================== Spoke Deploy Reader ====================

  function test_readSpoke() public view {
    ConfigReader.SpokeDeployConfig memory s = json.readSpoke(0);
    _assertStr(s.key, 'TEST_SPOKE', 'key');
    assertEq(s.oracleDecimals, 8);
    assertEq(s.maxUserReservesLimit, 128);
  }

  // ==================== Spoke Registration Reader ====================

  function test_readSpokeRegistration() public view {
    ConfigReader.SpokeRegistrationConfig memory r = json.readSpokeRegistration(0);
    _assertStr(r.assetKey, 'WETH', 'assetKey');
    _assertStr(r.hubKey, 'TEST_HUB', 'hubKey');
    _assertStr(r.spokeKey, 'TEST_SPOKE', 'spokeKey');
    assertEq(r.addCap, 225);
    assertEq(r.drawCap, 200);
    assertEq(r.riskPremiumThreshold, 100000);
    assertTrue(r.active);
    assertFalse(r.halted);
  }

  // ==================== Reserve Reader ====================

  function test_readReserve_weth() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(0);
    _assertStr(r.spokeKey, 'TEST_SPOKE', 'spokeKey');
    _assertStr(r.assetKey, 'WETH', 'assetKey');
    assertTrue(r.borrowable);
    assertEq(r.collateralRisk, 50_00);
    assertEq(r.collateralFactor, 80_00);
    assertEq(r.maxLiquidationBonus, 105_00); // from defaults
    assertEq(r.liquidationFee, 10_00);
    assertTrue(r.receiveSharesEnabled);
    assertFalse(r.frozen);
    assertFalse(r.paused);
  }

  function test_readReserve_usdc() public view {
    ConfigReader.ReserveConfig memory r = json.readReserve(1);
    _assertStr(r.assetKey, 'USDC', 'assetKey');
    assertEq(r.collateralFactor, 85_00);
    assertEq(r.maxLiquidationBonus, 104_00); // per-item
  }

  // ==================== Liquidation Config ====================

  function test_readLiquidationConfig() public view {
    ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(0);
    assertEq(lc.targetHealthFactor, 1.1e18);
    assertEq(lc.healthFactorForMaxBonus, 0.95e18);
    assertEq(lc.liquidationBonusFactor, 100_00);
  }

  // ==================== Periphery ====================

  function test_periphery() public view {
    assertFalse(json.deploySignatureGateway());
    assertFalse(json.deployNativeTokenGateway());
    _assertStr(json.nativeTokenKey(), 'WETH', 'nativeTokenKey');
  }

  // ==================== Default Resolution ====================

  function test_defaultResolution_liquidityFee() public view {
    assertEq(json.readAsset(0).liquidityFee, 10_00); // default
    assertEq(json.readAsset(1).liquidityFee, 5_00); // override
  }

  // ==================== String Utilities ====================

  function test_trimEnd() public pure {
    assertTrue(_strEq(ConfigReader.trimEnd('TEST_HUB', 4), 'TEST'));
  }
}
