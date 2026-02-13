// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ConfigReaderWrapper} from 'tests/scripts/libs/ConfigReader/ConfigReaderWrapper.sol';

/// @title ConfigReaderUnitTest
/// @notice Unit and fuzz tests for the ConfigReader library via a wrapper contract.
///         Validates trimEnd, default resolution, existence checks, and roundtrip
///         parsing of dynamically-generated JSON with fuzzed values.
contract ConfigReaderUnitTest is Test {
  using ConfigReader for string;

  ConfigReaderWrapper public wrapper;

  function setUp() public {
    wrapper = new ConfigReaderWrapper();
  }

  // ==================== trimEnd ====================

  function test_trimEnd_basic() public view {
    assertEq(keccak256(bytes(wrapper.trimEnd('HELLO_WORLD', 6))), keccak256(bytes('HELLO')));
  }

  function test_trimEnd_one() public view {
    assertEq(keccak256(bytes(wrapper.trimEnd('AB', 1))), keccak256(bytes('A')));
  }

  function test_trimEnd_zero_reverts() public {
    // trimEnd requires b.length > n, so trimEnd("A", 1) should revert (length 1 > 1 is false)
    vm.expectRevert();
    wrapper.trimEnd('A', 1);
  }

  /// @notice Fuzz: trimEnd(str, n) returns a string of length (str.length - n)
  ///         when n < str.length.
  function testFuzz_trimEnd_length(string memory str, uint256 n) public view {
    uint256 len = bytes(str).length;
    // trimEnd requires len > n, and len must be > 0
    vm.assume(len > 0);
    vm.assume(n < len);

    string memory result = wrapper.trimEnd(str, n);
    assertEq(bytes(result).length, len - n);
  }

  /// @notice Fuzz: trimEnd preserves the first (len - n) bytes exactly.
  function testFuzz_trimEnd_preservesPrefix(string memory str, uint256 n) public view {
    uint256 len = bytes(str).length;
    vm.assume(len > 0);
    vm.assume(n < len);

    string memory result = wrapper.trimEnd(str, n);
    bytes memory original = bytes(str);
    bytes memory trimmed = bytes(result);

    for (uint256 i; i < trimmed.length; i++) {
      assertEq(uint8(trimmed[i]), uint8(original[i]));
    }
  }

  /// @notice Fuzz: trimEnd with n >= str.length always reverts.
  function testFuzz_trimEnd_revertsOnOverflow(string memory str, uint256 n) public {
    uint256 len = bytes(str).length;
    vm.assume(n >= len);

    vm.expectRevert();
    wrapper.trimEnd(str, n);
  }

  // ==================== Existence Checks ====================

  function test_existenceChecks_emptyArrays() public view {
    string memory json = _minimalJson();
    assertFalse(wrapper.hubExists(json, 0));
    assertFalse(wrapper.spokeExists(json, 0));
    assertFalse(wrapper.assetExists(json, 0));
    assertFalse(wrapper.spokeRegistrationExists(json, 0));
    assertFalse(wrapper.reserveExists(json, 0));
  }

  function test_existenceChecks_withItems() public view {
    string memory json = _standardJson();
    assertTrue(wrapper.hubExists(json, 0));
    assertFalse(wrapper.hubExists(json, 1));
    assertTrue(wrapper.spokeExists(json, 0));
    assertFalse(wrapper.spokeExists(json, 1));
    assertTrue(wrapper.assetExists(json, 0));
    assertFalse(wrapper.assetExists(json, 1));
  }

  /// @notice Fuzz: existence check at any index > 0 on single-item arrays returns false.
  function testFuzz_existenceCheck_outOfBounds(uint256 i) public view {
    vm.assume(i > 0);
    vm.assume(i < 1000); // keep vm.toString reasonable
    string memory json = _standardJson();
    assertFalse(wrapper.hubExists(json, i));
    assertFalse(wrapper.spokeExists(json, i));
    assertFalse(wrapper.assetExists(json, i));
  }

  // ==================== Key Accessors ====================

  function test_hubKey() public view {
    string memory json = _standardJson();
    assertEq(keccak256(bytes(wrapper.hubKey(json, 0))), keccak256(bytes('FUZZ_HUB')));
  }

  function test_spokeKey() public view {
    string memory json = _standardJson();
    assertEq(keccak256(bytes(wrapper.spokeKey(json, 0))), keccak256(bytes('FUZZ_SPOKE')));
  }

  function test_tokenKeys() public view {
    string memory json = _standardJson();
    string[] memory keys = wrapper.tokenKeys(json);
    assertEq(keys.length, 1);
  }

  function test_tokenAddress() public view {
    string memory json = _standardJson();
    assertEq(wrapper.tokenAddress(json, 'WETH'), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  }

  // ==================== Infrastructure ====================

  function test_readInfrastructure() public view {
    string memory json = _standardJson();
    ConfigReader.InfrastructureConfig memory infra = wrapper.readInfrastructure(json);
    assertEq(infra.accessManagerAdmin, address(1));
    assertEq(infra.hubConfiguratorAdmin, address(2));
    assertEq(infra.gatewayOwner, address(0)); // not set → default
  }

  // ==================== Asset Reader with Fuzzed Values ====================

  /// @notice Fuzz: asset liquidityFee roundtrips through JSON with default resolution.
  function testFuzz_readAsset_liquidityFee(uint16 fee) public view {
    string memory json = _jsonWithAssetFee(fee);
    ConfigReader.AssetConfig memory a = wrapper.readAsset(json, 0);
    assertEq(a.liquidityFee, fee);
  }

  /// @notice Fuzz: asset IR data roundtrips correctly.
  function testFuzz_readAsset_irData(
    uint16 optimalUsage,
    uint32 baseRate,
    uint32 slope1,
    uint32 slope2
  ) public view {
    string memory json = _jsonWithIrData(optimalUsage, baseRate, slope1, slope2);
    ConfigReader.AssetConfig memory a = wrapper.readAsset(json, 0);
    assertEq(a.irData.optimalUsageRatio, optimalUsage);
    assertEq(a.irData.baseVariableBorrowRate, baseRate);
    assertEq(a.irData.variableRateSlope1, slope1);
    assertEq(a.irData.variableRateSlope2, slope2);
  }

  // ==================== Reserve Reader with Fuzzed Values ====================

  /// @notice Fuzz: reserve collateralRisk and collateralFactor roundtrip.
  function testFuzz_readReserve_collateral(uint24 risk, uint16 factor) public view {
    string memory json = _jsonWithReserve(risk, factor);
    ConfigReader.ReserveConfig memory r = wrapper.readReserve(json, 0);
    assertEq(r.collateralRisk, risk);
    assertEq(r.collateralFactor, factor);
  }

  /// @notice Fuzz: reserve maxLiquidationBonus per-item override roundtrips.
  function testFuzz_readReserve_maxLiquidationBonus(uint32 bonus) public view {
    string memory json = _jsonWithReserveBonus(bonus);
    ConfigReader.ReserveConfig memory r = wrapper.readReserve(json, 0);
    assertEq(r.maxLiquidationBonus, bonus);
  }

  // ==================== Spoke Config with Fuzzed Values ====================

  /// @notice Fuzz: spoke maxUserReservesLimit roundtrips.
  function testFuzz_readSpoke_maxReserves(uint16 limit) public view {
    string memory json = _jsonWithSpokeLimit(limit);
    ConfigReader.SpokeDeployConfig memory s = wrapper.readSpoke(json, 0);
    assertEq(s.maxUserReservesLimit, limit);
  }

  // ==================== Spoke Registration with Fuzzed Values ====================

  /// @notice Fuzz: spoke registration caps roundtrip.
  function testFuzz_readSpokeRegistration_caps(uint40 addCap, uint40 drawCap) public view {
    string memory json = _jsonWithSpokeRegistrationCaps(addCap, drawCap);
    ConfigReader.SpokeRegistrationConfig memory r = wrapper.readSpokeRegistration(json, 0);
    assertEq(r.addCap, addCap);
    assertEq(r.drawCap, drawCap);
  }

  // ==================== Default Resolution ====================

  function test_defaultResolution_assetFee_fromDefaults() public view {
    // JSON with defaults.asset.liquidityFee=500, no per-item override
    string memory json = _jsonWithAssetFeeDefaults(500);
    ConfigReader.AssetConfig memory a = wrapper.readAsset(json, 0);
    assertEq(a.liquidityFee, 500);
  }

  function test_defaultResolution_assetFee_hardcoded() public view {
    // JSON with no defaults section and no per-item override → hardcoded 1000
    string memory json = _jsonWithAssetFeeNoDefaults();
    ConfigReader.AssetConfig memory a = wrapper.readAsset(json, 0);
    assertEq(a.liquidityFee, 1000);
  }

  function test_defaultResolution_perItemOverridesDefaults() public view {
    // JSON with defaults.asset.liquidityFee=500 AND per-item liquidityFee=800
    string memory json = _jsonWithAssetFeeBoth(500, 800);
    ConfigReader.AssetConfig memory a = wrapper.readAsset(json, 0);
    assertEq(a.liquidityFee, 800); // per-item wins
  }

  /// @notice Fuzz: per-item always overrides defaults.
  function testFuzz_defaultResolution_perItemWins(uint16 dflt, uint16 perItem) public view {
    string memory json = _jsonWithAssetFeeBoth(dflt, perItem);
    ConfigReader.AssetConfig memory a = wrapper.readAsset(json, 0);
    assertEq(a.liquidityFee, perItem);
  }

  // ==================== Liquidation Config ====================

  function test_liquidationConfig_fromSpoke() public view {
    string memory json = _jsonWithLiquidationConfig(1.1e18, 0.95e18, 10000);
    ISpoke.LiquidationConfig memory lc = wrapper.readLiquidationConfig(json, 0);
    assertEq(lc.targetHealthFactor, 1.1e18);
    assertEq(lc.healthFactorForMaxBonus, 0.95e18);
    assertEq(lc.liquidationBonusFactor, 10000);
  }

  // ==================== JSON Builders ====================

  function _minimalJson() internal pure returns (string memory) {
    return
      '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
      '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
      '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
      '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
      '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005",'
      '"salt":"min"},'
      '"tokens":{},'
      '"hubs":[],"spokes":[],"assets":[],"spokeRegistrations":[],"reserves":[],"periphery":{}}';
  }

  function _standardJson() internal pure returns (string memory) {
    return
      '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
      '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
      '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
      '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
      '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005",'
      '"salt":"test"},'
      '"defaults":{"tokenize":{"enabled":false}},'
      '"tokens":{"WETH":{"address":"0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2","priceFeed":"0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"}},'
      '"hubs":[{"key":"FUZZ_HUB"}],'
      '"spokes":[{"key":"FUZZ_SPOKE"}],'
      '"assets":[{"tokenKey":"WETH","hubKey":"FUZZ_HUB","irData":{"optimalUsageRatio":9000,"baseVariableBorrowRate":100,"variableRateSlope1":700,"variableRateSlope2":30000}}],'
      '"spokeRegistrations":[{"assetKey":"WETH","hubKey":"FUZZ_HUB","spokeKey":"FUZZ_SPOKE","addCap":225,"drawCap":200}],'
      '"reserves":[{"spokeKey":"FUZZ_SPOKE","hubKey":"FUZZ_HUB","assetKey":"WETH","borrowable":true,"collateralRisk":5000,"collateralFactor":8000}],'
      '"periphery":{"nativeTokenKey":"WETH"}}';
  }

  function _jsonWithAssetFee(uint16 fee) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
        '"hubs":[],"spokes":[],'
        '"assets":[{"tokenKey":"T","hubKey":"H","liquidityFee":',
        vm.toString(uint256(fee)),
        ',"irData":{"optimalUsageRatio":9000,"baseVariableBorrowRate":0,"variableRateSlope1":0,"variableRateSlope2":0}}],'
        '"spokeRegistrations":[],"reserves":[],"periphery":{}}'
      );
  }

  function _jsonWithIrData(
    uint16 optimal,
    uint32 baseRate,
    uint32 slope1,
    uint32 slope2
  ) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
        '"hubs":[],"spokes":[],'
        '"assets":[{"tokenKey":"T","hubKey":"H","irData":{"optimalUsageRatio":',
        vm.toString(uint256(optimal)),
        ',"baseVariableBorrowRate":',
        vm.toString(uint256(baseRate)),
        string.concat(
          ',"variableRateSlope1":',
          vm.toString(uint256(slope1)),
          ',"variableRateSlope2":',
          vm.toString(uint256(slope2)),
          '}}],"spokeRegistrations":[],"reserves":[],"periphery":{}}'
        )
      );
  }

  function _jsonWithReserve(uint24 risk, uint16 factor) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
        '"hubs":[],"spokes":[],"assets":[],"spokeRegistrations":[],'
        '"reserves":[{"spokeKey":"S","hubKey":"H","assetKey":"T","borrowable":true,"collateralRisk":',
        vm.toString(uint256(risk)),
        ',"collateralFactor":',
        vm.toString(uint256(factor)),
        '}],"periphery":{}}'
      );
  }

  function _jsonWithReserveBonus(uint32 bonus) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
        '"hubs":[],"spokes":[],"assets":[],"spokeRegistrations":[],'
        '"reserves":[{"spokeKey":"S","hubKey":"H","assetKey":"T","borrowable":true,"collateralRisk":5000,"collateralFactor":8000,"maxLiquidationBonus":',
        vm.toString(uint256(bonus)),
        '}],"periphery":{}}'
      );
  }

  function _jsonWithSpokeLimit(uint16 limit) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{},"hubs":[],'
        '"spokes":[{"key":"S","maxUserReservesLimit":',
        vm.toString(uint256(limit)),
        '}],"assets":[],"spokeRegistrations":[],"reserves":[],"periphery":{}}'
      );
  }

  function _jsonWithSpokeRegistrationCaps(
    uint40 addCap,
    uint40 drawCap
  ) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{},"hubs":[],"spokes":[],"assets":[],'
        '"spokeRegistrations":[{"assetKey":"T","hubKey":"H","spokeKey":"S","addCap":',
        vm.toString(uint256(addCap)),
        ',"drawCap":',
        vm.toString(uint256(drawCap)),
        '}],"reserves":[],"periphery":{}}'
      );
  }

  function _jsonWithAssetFeeDefaults(uint16 dflt) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"defaults":{"asset":{"liquidityFee":',
        vm.toString(uint256(dflt)),
        '}},'
        '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
        '"hubs":[],"spokes":[],'
        '"assets":[{"tokenKey":"T","hubKey":"H","irData":{"optimalUsageRatio":9000,"baseVariableBorrowRate":0,"variableRateSlope1":0,"variableRateSlope2":0}}],'
        '"spokeRegistrations":[],"reserves":[],"periphery":{}}'
      );
  }

  function _jsonWithAssetFeeNoDefaults() internal pure returns (string memory) {
    return
      '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
      '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
      '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
      '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
      '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
      '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
      '"hubs":[],"spokes":[],'
      '"assets":[{"tokenKey":"T","hubKey":"H","irData":{"optimalUsageRatio":9000,"baseVariableBorrowRate":0,"variableRateSlope1":0,"variableRateSlope2":0}}],'
      '"spokeRegistrations":[],"reserves":[],"periphery":{}}';
  }

  function _jsonWithAssetFeeBoth(
    uint16 dflt,
    uint16 perItem
  ) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"defaults":{"asset":{"liquidityFee":',
        vm.toString(uint256(dflt)),
        '}},'
        '"tokens":{"T":{"address":"0x0000000000000000000000000000000000000001"}},'
        '"hubs":[],"spokes":[],'
        '"assets":[{"tokenKey":"T","hubKey":"H","liquidityFee":',
        vm.toString(uint256(perItem)),
        ',"irData":{"optimalUsageRatio":9000,"baseVariableBorrowRate":0,"variableRateSlope1":0,"variableRateSlope2":0}}],'
        '"spokeRegistrations":[],"reserves":[],"periphery":{}}'
      );
  }

  function _jsonWithLiquidationConfig(
    uint128 targetHF,
    uint64 hfForMaxBonus,
    uint16 bonusFactor
  ) internal pure returns (string memory) {
    return
      string.concat(
        '{"infrastructure":{"accessManagerAdmin":"0x0000000000000000000000000000000000000001",'
        '"hubConfiguratorAdmin":"0x0000000000000000000000000000000000000002",'
        '"spokeConfiguratorAdmin":"0x0000000000000000000000000000000000000003",'
        '"treasurySpokeOwner":"0x0000000000000000000000000000000000000004",'
        '"spokeProxyAdminOwner":"0x0000000000000000000000000000000000000005","salt":"t"},'
        '"tokens":{},"hubs":[],'
        '"spokes":[{"key":"S","liquidationConfig":{"targetHealthFactor":',
        vm.toString(uint256(targetHF)),
        ',"healthFactorForMaxBonus":',
        vm.toString(uint256(hfForMaxBonus)),
        string.concat(
          ',"liquidationBonusFactor":',
          vm.toString(uint256(bonusFactor)),
          '}}],"assets":[],"spokeRegistrations":[],"reserves":[],"periphery":{}}'
        )
      );
  }
}
