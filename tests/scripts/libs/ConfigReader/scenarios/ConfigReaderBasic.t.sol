// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: No-tokenization deployment — tokenization disabled globally.
///
///   Config: config/test-hub-spoke-no-tokenization.json
///   - 1 hub (PRIME_HUB), 1 spoke (PRIME_SPOKE), 2 tokens (WETH, USDC)
///   - defaults.tokenize.enabled = false → all assets inherit disabled
///   - No per-item tokenize overrides
///   - USDC has liquidityFee=500 override (default is 1000)
///   - infrastructure.gatewayOwner and .nativeWrapper not set → default to address(0)
///
///   Tests verify:
///   - Global tokenization disable propagates to all assets
///   - Optional infrastructure fields default to address(0)
///   - liquidityFee override still works with tokenization disabled
///   - IR data fields parsed correctly
///   - Spoke registration caps parsed for both assets
///   - Liquidation config parsed from spoke-level section
contract ConfigReaderBasicTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-hub-spoke-no-tokenization.json');
  }

  function test_basic_counts() public view {
    assertEq(_countHubs(), 1);
    assertEq(_countSpokes(), 1);
    assertEq(_countAssets(), 2);
    assertEq(_countSpokeRegistrations(), 2);
    assertEq(_countReserves(), 2);
  }

  function test_basic_noTokenization() public view {
    // defaults.tokenize.enabled = false → both assets should inherit
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    assertFalse(weth.tokenizeEnabled);

    ConfigReader.AssetConfig memory usdc = json.readAsset(1);
    assertFalse(usdc.tokenizeEnabled);
  }

  function test_basic_liquidityFeeOverride() public view {
    assertEq(json.readAsset(0).liquidityFee, 10_00); // default
    assertEq(json.readAsset(1).liquidityFee, 5_00); // per-item override
  }

  function test_basic_infraOptionals() public view {
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();
    // gatewayOwner and nativeWrapper not set → should default to address(0)
    assertEq(infra.gatewayOwner, address(0));
    assertEq(infra.nativeWrapper, address(0));
  }

  function test_basic_irDataValues() public view {
    ConfigReader.AssetConfig memory weth = json.readAsset(0);
    assertEq(weth.irData.optimalUsageRatio, 90_00);
    assertEq(weth.irData.baseVariableBorrowRate, 1_00);
    assertEq(weth.irData.variableRateSlope1, 7_00);
    assertEq(weth.irData.variableRateSlope2, 300_00);

    ConfigReader.AssetConfig memory usdc = json.readAsset(1);
    assertEq(usdc.irData.optimalUsageRatio, 92_00);
    assertEq(usdc.irData.baseVariableBorrowRate, 0);
    assertEq(usdc.irData.variableRateSlope1, 5_50);
    assertEq(usdc.irData.variableRateSlope2, 400_00);
  }

  function test_basic_spokeRegistrations() public view {
    ConfigReader.SpokeRegistrationConfig memory wethReg = json.readSpokeRegistration(0);
    _assertStr(wethReg.assetKey, 'WETH', 'reg0.assetKey');
    assertEq(wethReg.addCap, 225);
    assertEq(wethReg.drawCap, 200);

    ConfigReader.SpokeRegistrationConfig memory usdcReg = json.readSpokeRegistration(1);
    _assertStr(usdcReg.assetKey, 'USDC', 'reg1.assetKey');
    assertEq(usdcReg.addCap, 500000);
    assertEq(usdcReg.drawCap, 400000);
  }

  function test_basic_liquidationConfig() public view {
    ISpoke.LiquidationConfig memory lc = json.readLiquidationConfig(0);
    assertEq(lc.targetHealthFactor, 1.1e18);
    assertEq(lc.healthFactorForMaxBonus, 0.95e18);
    assertEq(lc.liquidationBonusFactor, 100_00);
  }
}
