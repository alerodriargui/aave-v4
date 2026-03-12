// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {stdJson} from 'forge-std/StdJson.sol';
import {Vm} from 'forge-std/Vm.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title ConfigReader
/// @notice Library for reading deployment config JSON with 3-level default resolution:
///         per-item field → defaults section → hardcoded constant.
///         Strict variants revert if any defaultable field is missing.
library ConfigReader {
  using stdJson for string;
  using SafeCast for uint;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // ==================== Default Constants ====================

  uint16 internal constant DEFAULT_LIQUIDITY_FEE = 1000;
  bool internal constant DEFAULT_TOKENIZE_ENABLED = true;
  uint40 internal constant DEFAULT_TOKENIZE_ADD_CAP = type(uint40).max;
  uint8 internal constant DEFAULT_ORACLE_DECIMALS = 8;
  uint16 internal constant DEFAULT_MAX_USER_RESERVES_LIMIT = 128;
  bool internal constant DEFAULT_REGISTER_ON_POSITION_MANAGERS = true;
  uint24 internal constant DEFAULT_RISK_PREMIUM_THRESHOLD = 100_000;
  bool internal constant DEFAULT_SPOKE_REG_ACTIVE = true;
  bool internal constant DEFAULT_SPOKE_REG_HALTED = false;
  uint32 internal constant DEFAULT_MAX_LIQUIDATION_BONUS = 10500;
  uint16 internal constant DEFAULT_RESERVE_LIQUIDATION_FEE = 1000;
  bool internal constant DEFAULT_RECEIVE_SHARES_ENABLED = true;
  bool internal constant DEFAULT_FROZEN = false;
  bool internal constant DEFAULT_PAUSED = false;
  uint128 internal constant DEFAULT_TARGET_HEALTH_FACTOR = 1.05e18;
  uint64 internal constant DEFAULT_HEALTH_FACTOR_FOR_MAX_BONUS = 0.7e18;
  uint16 internal constant DEFAULT_LIQUIDATION_BONUS_FACTOR = 2000;

  // ==================== Structs ====================

  struct AssetConfig {
    string tokenKey;
    string hubKey;
    uint16 liquidityFee;
    IAssetInterestRateStrategy.InterestRateData irData;
    bool tokenizeEnabled;
    uint40 tokenizeAddCap;
  }

  struct SpokeDeployConfig {
    string key;
    uint8 oracleDecimals;
    uint16 maxUserReservesLimit;
    bool registerOnPositionManagers;
  }

  struct SpokeRegConfig {
    string assetKey;
    string hubKey;
    string spokeKey;
    uint40 addCap;
    uint40 drawCap;
    uint24 riskPremiumThreshold;
    bool active;
    bool halted;
  }

  struct ReserveConfig {
    string spokeKey;
    string assetKey;
    string hubKey;
    bool borrowable;
    uint32 maxLiquidationBonus;
    uint24 collateralRisk;
    uint16 collateralFactor;
    uint16 liquidationFee;
    bool receiveSharesEnabled;
    bool frozen;
    bool paused;
  }

  // ==================== Resolution Helpers ====================

  /// @dev 3-level resolution: path → defaultPath → hardcoded fallback.
  ///      If strict=true, reads path directly (reverts if missing).
  ///      If defaultPath is empty, skips defaults section lookup.
  function _resolveUint(
    string memory json,
    string memory path,
    string memory defaultPath,
    uint fallback_,
    bool strict
  ) private view returns (uint) {
    if (strict) return json.readUint(path);
    if (json.keyExists(path)) return json.readUint(path);
    if (bytes(defaultPath).length > 0) return json.readUintOr(defaultPath, fallback_);
    return fallback_;
  }

  function _resolveBool(
    string memory json,
    string memory path,
    string memory defaultPath,
    bool fallback_,
    bool strict
  ) private view returns (bool) {
    if (strict) return json.readBool(path);
    if (json.keyExists(path)) return json.readBool(path);
    if (bytes(defaultPath).length > 0) return json.readBoolOr(defaultPath, fallback_);
    return fallback_;
  }

  // ==================== Existence Checks ====================

  function hubExists(string memory json, uint i) internal view returns (bool) {
    return json.keyExists(string.concat('.hubs[', vm.toString(i), ']'));
  }

  function spokeExists(string memory json, uint i) internal view returns (bool) {
    return json.keyExists(string.concat('.spokes[', vm.toString(i), ']'));
  }

  function assetExists(string memory json, uint i) internal view returns (bool) {
    return json.keyExists(string.concat('.assets[', vm.toString(i), ']'));
  }

  function spokeRegExists(string memory json, uint i) internal view returns (bool) {
    return json.keyExists(string.concat('.spokeRegistrations[', vm.toString(i), ']'));
  }

  function reserveExists(string memory json, uint i) internal view returns (bool) {
    return json.keyExists(string.concat('.reserves[', vm.toString(i), ']'));
  }

  // ==================== Simple Accessors ====================

  function hubKey(string memory json, uint i) internal pure returns (string memory) {
    return json.readString(string.concat('.hubs[', vm.toString(i), '].key'));
  }

  function spokeKey(string memory json, uint i) internal pure returns (string memory) {
    return json.readString(string.concat('.spokes[', vm.toString(i), '].key'));
  }

  function tokenKeys(string memory json) internal pure returns (string[] memory) {
    return vm.parseJsonKeys(json, '.tokens');
  }

  function tokenAddress(string memory json, string memory key) internal pure returns (address) {
    return json.readAddress(string.concat('.tokens.', key, '.address'));
  }

  function tokenPriceFeed(string memory json, string memory key) internal view returns (address) {
    return json.readAddressOr(string.concat('.tokens.', key, '.priceFeed'), address(0));
  }

  function deploySignatureGateway(string memory json) internal view returns (bool) {
    return json.readBoolOr('.periphery.deploySignatureGateway', false);
  }

  function deployNativeTokenGateway(string memory json) internal view returns (bool) {
    return json.readBoolOr('.periphery.deployNativeTokenGateway', false);
  }

  function deployAllowancePositionManager(string memory json) internal view returns (bool) {
    return json.readBoolOr('.periphery.deployAllowancePositionManager', false);
  }

  function deploySupplyRepayPositionManager(string memory json) internal view returns (bool) {
    return json.readBoolOr('.periphery.deploySupplyRepayPositionManager', false);
  }

  function deployConfigPositionManager(string memory json) internal view returns (bool) {
    return json.readBoolOr('.periphery.deployConfigPositionManager', false);
  }

  function nativeTokenKey(string memory json) internal pure returns (string memory) {
    return json.readString('.periphery.nativeTokenKey');
  }

  // ==================== Asset Reader ====================

  function readAsset(string memory json, uint i) internal view returns (AssetConfig memory) {
    return _readAsset(json, i, false);
  }

  function readAssetStrict(string memory json, uint i) internal view returns (AssetConfig memory) {
    return _readAsset(json, i, true);
  }

  function _readAsset(
    string memory json,
    uint i,
    bool strict
  ) private view returns (AssetConfig memory) {
    string memory base = string.concat('.assets[', vm.toString(i), ']');
    return
      AssetConfig({
        tokenKey: json.readString(string.concat(base, '.tokenKey')),
        hubKey: json.readString(string.concat(base, '.hubKey')),
        liquidityFee: _resolveUint(
          json,
          string.concat(base, '.liquidityFee'),
          '.defaults.asset.liquidityFee',
          DEFAULT_LIQUIDITY_FEE,
          strict
        ).toUint16(),
        irData: IAssetInterestRateStrategy.InterestRateData({
          optimalUsageRatio: json
            .readUint(string.concat(base, '.irData.optimalUsageRatio'))
            .toUint16(),
          baseVariableBorrowRate: json
            .readUint(string.concat(base, '.irData.baseVariableBorrowRate'))
            .toUint32(),
          variableRateSlope1: json
            .readUint(string.concat(base, '.irData.variableRateSlope1'))
            .toUint32(),
          variableRateSlope2: json
            .readUint(string.concat(base, '.irData.variableRateSlope2'))
            .toUint32()
        }),
        tokenizeEnabled: _resolveBool(
          json,
          string.concat(base, '.tokenize.enabled'),
          '.defaults.tokenize.enabled',
          DEFAULT_TOKENIZE_ENABLED,
          strict
        ),
        tokenizeAddCap: _resolveUint(
          json,
          string.concat(base, '.tokenize.addCap'),
          '.defaults.tokenize.addCap',
          DEFAULT_TOKENIZE_ADD_CAP,
          strict
        ).toUint40()
      });
  }

  // ==================== Spoke Deploy Reader ====================

  function readSpoke(string memory json, uint i) internal view returns (SpokeDeployConfig memory) {
    return _readSpoke(json, i, false);
  }

  function readSpokeStrict(
    string memory json,
    uint i
  ) internal view returns (SpokeDeployConfig memory) {
    return _readSpoke(json, i, true);
  }

  function _readSpoke(
    string memory json,
    uint i,
    bool strict
  ) private view returns (SpokeDeployConfig memory) {
    string memory base = string.concat('.spokes[', vm.toString(i), ']');
    return
      SpokeDeployConfig({
        key: json.readString(string.concat(base, '.key')),
        oracleDecimals: _resolveUint(
          json,
          string.concat(base, '.oracleDecimals'),
          '.defaults.spoke.oracleDecimals',
          DEFAULT_ORACLE_DECIMALS,
          strict
        ).toUint8(),
        maxUserReservesLimit: _resolveUint(
          json,
          string.concat(base, '.maxUserReservesLimit'),
          '.defaults.spoke.maxUserReservesLimit',
          DEFAULT_MAX_USER_RESERVES_LIMIT,
          strict
        ).toUint16(),
        registerOnPositionManagers: _resolveBool(
          json,
          string.concat(base, '.registerOnPositionManagers'),
          '',
          DEFAULT_REGISTER_ON_POSITION_MANAGERS,
          strict
        )
      });
  }

  // ==================== Spoke Registration Reader ====================

  function readSpokeReg(string memory json, uint i) internal view returns (SpokeRegConfig memory) {
    return _readSpokeReg(json, i, false);
  }

  function readSpokeRegStrict(
    string memory json,
    uint i
  ) internal view returns (SpokeRegConfig memory) {
    return _readSpokeReg(json, i, true);
  }

  function _readSpokeReg(
    string memory json,
    uint i,
    bool strict
  ) private view returns (SpokeRegConfig memory) {
    string memory base = string.concat('.spokeRegistrations[', vm.toString(i), ']');
    return
      SpokeRegConfig({
        assetKey: json.readString(string.concat(base, '.assetKey')),
        hubKey: json.readString(string.concat(base, '.hubKey')),
        spokeKey: json.readString(string.concat(base, '.spokeKey')),
        addCap: json.readUint(string.concat(base, '.addCap')).toUint40(),
        drawCap: json.readUint(string.concat(base, '.drawCap')).toUint40(),
        riskPremiumThreshold: _resolveUint(
          json,
          string.concat(base, '.riskPremiumThreshold'),
          '.defaults.spokeRegistration.riskPremiumThreshold',
          DEFAULT_RISK_PREMIUM_THRESHOLD,
          strict
        ).toUint24(),
        active: _resolveBool(
          json,
          string.concat(base, '.active'),
          '.defaults.spokeRegistration.active',
          DEFAULT_SPOKE_REG_ACTIVE,
          strict
        ),
        halted: _resolveBool(
          json,
          string.concat(base, '.halted'),
          '.defaults.spokeRegistration.halted',
          DEFAULT_SPOKE_REG_HALTED,
          strict
        )
      });
  }

  // ==================== Reserve Reader ====================

  function readReserve(string memory json, uint i) internal view returns (ReserveConfig memory) {
    return _readReserve(json, i, false);
  }

  function readReserveStrict(
    string memory json,
    uint i
  ) internal view returns (ReserveConfig memory) {
    return _readReserve(json, i, true);
  }

  function _readReserve(
    string memory json,
    uint i,
    bool strict
  ) private view returns (ReserveConfig memory) {
    string memory base = string.concat('.reserves[', vm.toString(i), ']');
    return
      ReserveConfig({
        spokeKey: json.readString(string.concat(base, '.spokeKey')),
        assetKey: json.readString(string.concat(base, '.assetKey')),
        hubKey: json.readString(string.concat(base, '.hubKey')),
        borrowable: json.readBool(string.concat(base, '.borrowable')),
        collateralRisk: json.readUint(string.concat(base, '.collateralRisk')).toUint24(),
        collateralFactor: json.readUint(string.concat(base, '.collateralFactor')).toUint16(),
        maxLiquidationBonus: _resolveUint(
          json,
          string.concat(base, '.maxLiquidationBonus'),
          '.defaults.reserve.maxLiquidationBonus',
          DEFAULT_MAX_LIQUIDATION_BONUS,
          strict
        ).toUint32(),
        liquidationFee: _resolveUint(
          json,
          string.concat(base, '.liquidationFee'),
          '.defaults.reserve.liquidationFee',
          DEFAULT_RESERVE_LIQUIDATION_FEE,
          strict
        ).toUint16(),
        receiveSharesEnabled: _resolveBool(
          json,
          string.concat(base, '.receiveSharesEnabled'),
          '.defaults.reserve.receiveSharesEnabled',
          DEFAULT_RECEIVE_SHARES_ENABLED,
          strict
        ),
        frozen: _resolveBool(
          json,
          string.concat(base, '.frozen'),
          '.defaults.reserve.frozen',
          DEFAULT_FROZEN,
          strict
        ),
        paused: _resolveBool(
          json,
          string.concat(base, '.paused'),
          '.defaults.reserve.paused',
          DEFAULT_PAUSED,
          strict
        )
      });
  }

  // ==================== Liquidation Config Reader ====================

  function readLiquidationConfig(
    string memory json,
    uint i
  ) internal view returns (ISpoke.LiquidationConfig memory) {
    return _readLiquidationConfig(json, i, false);
  }

  function readLiquidationConfigStrict(
    string memory json,
    uint i
  ) internal view returns (ISpoke.LiquidationConfig memory) {
    return _readLiquidationConfig(json, i, true);
  }

  function _readLiquidationConfig(
    string memory json,
    uint i,
    bool strict
  ) private view returns (ISpoke.LiquidationConfig memory lc) {
    string memory lcBase = string.concat('.spokes[', vm.toString(i), '].liquidationConfig');
    bool exists = json.keyExists(lcBase);
    if (!exists && strict) revert('liquidationConfig: missing (strict)');
    string memory defBase = '.defaults.spoke.liquidationConfig';
    if (!exists) {
      return
        ISpoke.LiquidationConfig({
          targetHealthFactor: json
            .readUintOr(string.concat(defBase, '.targetHealthFactor'), DEFAULT_TARGET_HEALTH_FACTOR)
            .toUint128(),
          healthFactorForMaxBonus: json
            .readUintOr(
              string.concat(defBase, '.healthFactorForMaxBonus'),
              DEFAULT_HEALTH_FACTOR_FOR_MAX_BONUS
            )
            .toUint64(),
          liquidationBonusFactor: json
            .readUintOr(
              string.concat(defBase, '.liquidationBonusFactor'),
              DEFAULT_LIQUIDATION_BONUS_FACTOR
            )
            .toUint16()
        });
    }
    lc = ISpoke.LiquidationConfig({
      targetHealthFactor: _resolveUint(
        json,
        string.concat(lcBase, '.targetHealthFactor'),
        string.concat(defBase, '.targetHealthFactor'),
        DEFAULT_TARGET_HEALTH_FACTOR,
        strict
      ).toUint128(),
      healthFactorForMaxBonus: _resolveUint(
        json,
        string.concat(lcBase, '.healthFactorForMaxBonus'),
        string.concat(defBase, '.healthFactorForMaxBonus'),
        DEFAULT_HEALTH_FACTOR_FOR_MAX_BONUS,
        strict
      ).toUint64(),
      liquidationBonusFactor: _resolveUint(
        json,
        string.concat(lcBase, '.liquidationBonusFactor'),
        string.concat(defBase, '.liquidationBonusFactor'),
        DEFAULT_LIQUIDATION_BONUS_FACTOR,
        strict
      ).toUint16()
    });
  }

  // ==================== String Utilities ====================

  function trimEnd(string memory str, uint n) internal pure returns (string memory) {
    bytes memory b = bytes(str);
    require(b.length > n);
    bytes memory result = new bytes(b.length - n);
    for (uint j; j < result.length; j++) result[j] = b[j];
    return string(result);
  }
}
