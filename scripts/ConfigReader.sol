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

  // ==================== Hub-Side Default Constants ====================
  // These defaults apply to Hub and HubConfigurator operations.

  // Asset liquidityFee in BPS — set via HubConfigurator.updateLiquidityFee()
  uint16 internal constant DEFAULT_LIQUIDITY_FEE = 10_00;

  // Whether to deploy an ERC-4626 tokenization spoke — set during HubConfigurator.addSpoke()
  bool internal constant DEFAULT_TOKENIZE_ENABLED = true;

  // Supply cap for tokenization spoke — set during HubConfigurator.addSpoke()
  uint40 internal constant DEFAULT_TOKENIZE_ADD_CAP = type(uint40).max;

  // ==================== Hub-Side Spoke Registration Defaults ====================
  // These defaults apply to spoke registration on the hub (IHub.SpokeConfig).

  // Risk premium threshold in ppm — set via HubConfigurator.updateSpokeRiskPremiumThreshold()
  uint24 internal constant DEFAULT_SPOKE_REGISTRATION_RISK_PREMIUM_THRESHOLD = 200_000;

  // Whether the spoke registration is active — set via HubConfigurator.updateSpokeActive()
  bool internal constant DEFAULT_SPOKE_REGISTRATION_ACTIVE = true;

  // Whether the spoke registration is halted — set via HubConfigurator.updateSpokeHalted()
  bool internal constant DEFAULT_SPOKE_REGISTRATION_HALTED = false;

  // ==================== Spoke-Side Default Constants ====================
  // These defaults apply to Spoke and SpokeConfigurator operations.

  // Oracle decimal precision — set during spoke deployment
  uint8 internal constant DEFAULT_ORACLE_DECIMALS = 8;

  // Maximum number of user reserves per spoke — set via SpokeConfigurator.updateMaxReserves()
  uint16 internal constant DEFAULT_MAX_USER_RESERVES_LIMIT = 128;

  // Whether to register the spoke on position managers — set during spoke deployment
  bool internal constant DEFAULT_REGISTER_ON_POSITION_MANAGERS = true;

  // ==================== Spoke-Side Reserve Default Constants ====================
  // These defaults apply to reserve configuration on spokes (SpokeConfigurator).

  // Max liquidation bonus in BPS — set via SpokeConfigurator.updateDynamicReserveConfig()
  uint32 internal constant DEFAULT_MAX_LIQUIDATION_BONUS = 105_00;

  // Liquidation fee in BPS — set via SpokeConfigurator.updateDynamicReserveConfig()
  uint16 internal constant DEFAULT_RESERVE_LIQUIDATION_FEE = 10_00;

  // Whether the reserve accepts share transfers — set via SpokeConfigurator.updateReserveConfig()
  bool internal constant DEFAULT_RECEIVE_SHARES_ENABLED = true;

  // Whether the reserve is frozen — set via SpokeConfigurator.updateReserveConfig()
  bool internal constant DEFAULT_FROZEN = false;

  // Whether the reserve is paused — set via SpokeConfigurator.updateReserveConfig()
  bool internal constant DEFAULT_PAUSED = false;

  // ==================== Spoke-Side Liquidation Config Defaults ====================
  // These defaults apply to per-spoke liquidation config (SpokeConfigurator).

  // Target health factor after liquidation — set via SpokeConfigurator.updateLiquidationConfig()
  uint128 internal constant DEFAULT_TARGET_HEALTH_FACTOR = 1.05e18;

  // Health factor threshold for maximum bonus — set via SpokeConfigurator.updateLiquidationConfig()
  uint64 internal constant DEFAULT_HEALTH_FACTOR_FOR_MAX_BONUS = 0.7e18;

  // Liquidation bonus scaling factor in BPS — set via SpokeConfigurator.updateLiquidationConfig()
  uint16 internal constant DEFAULT_LIQUIDATION_BONUS_FACTOR = 20_00;

  // ==================== Structs ====================

  /// @notice Asset configuration for listing on a hub.
  /// @param tokenKey Key referencing the token in the tokens registry (e.g., "WETH")
  /// @param hubKey Key referencing which hub to list this asset on (e.g., "PRIME_HUB")
  /// @param liquidityFee Fee in BPS charged on borrow interest, routed to fee receiver
  /// @param irData Interest rate model parameters (optimal ratio, base rate, slopes)
  /// @param tokenizeEnabled Whether to deploy an ERC-4626 tokenization spoke for this asset
  /// @param tokenizeAddCap Supply cap for the tokenization spoke
  struct AssetConfig {
    string tokenKey;
    string hubKey;
    uint16 liquidityFee;
    IAssetInterestRateStrategy.InterestRateData irData;
    bool tokenizeEnabled;
    uint40 tokenizeAddCap;
  }

  /// @notice Spoke deployment configuration.
  /// @param key Unique identifier for this spoke (e.g., "PRIME_SPOKE")
  /// @param oracleDecimals Decimal precision for the spoke's oracle
  /// @param maxUserReservesLimit Maximum number of reserves a user can hold on this spoke
  /// @param registerOnPositionManagers Whether to register with position managers on deploy
  struct SpokeDeployConfig {
    string key;
    uint8 oracleDecimals;
    uint16 maxUserReservesLimit;
    bool registerOnPositionManagers;
  }

  /// @notice Spoke registration configuration — registers a spoke on a hub for a given asset.
  /// @param assetKey Token key (must match an asset listed on the hub)
  /// @param hubKey Hub key this registration connects to
  /// @param spokeKey Spoke key that will be registered
  /// @param addCap Maximum supply cap the spoke can add to the hub
  /// @param drawCap Maximum amount the spoke can draw from the hub
  /// @param riskPremiumThreshold Risk premium threshold in ppm
  /// @param active Whether the spoke registration is active
  /// @param halted Whether the spoke registration is halted (emergency)
  struct SpokeRegistrationConfig {
    string assetKey;
    string hubKey;
    string spokeKey;
    uint40 addCap;
    uint40 drawCap;
    uint24 riskPremiumThreshold;
    bool active;
    bool halted;
  }

  /// @notice Reserve configuration on a spoke — lending/borrowing parameters.
  /// @param spokeKey Spoke key where this reserve lives
  /// @param assetKey Token key for this reserve's underlying asset
  /// @param hubKey Hub key this reserve's asset is listed on
  /// @param borrowable Whether the reserve allows borrowing
  /// @param maxLiquidationBonus Maximum liquidation bonus in BPS (e.g., 10500 = 105%)
  /// @param collateralRisk Risk weight for this collateral in BPS
  /// @param collateralFactor Loan-to-value ratio in BPS (e.g., 8000 = 80%)
  /// @param liquidationFee Fee in BPS taken during liquidation
  /// @param receiveSharesEnabled Whether the reserve accepts share transfers
  /// @param frozen Whether the reserve is frozen (no new supply/borrow)
  /// @param paused Whether the reserve is paused (no operations)
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

  /// @notice Infrastructure addresses and configuration for deployment.
  /// @param accessManagerAdmin Admin of the AccessManager (DEFAULT_ADMIN_ROLE holder)
  /// @param hubConfiguratorAdmin Admin for HubConfigurator granular roles
  /// @param spokeConfiguratorAdmin Admin for SpokeConfigurator granular roles
  /// @param treasurySpokeOwner Owner of the treasury spoke (fee receiver)
  /// @param spokeProxyAdminOwner Owner of spoke proxy admin contracts
  /// @param gatewayOwner Owner of gateway contracts (optional, defaults to address(0))
  /// @param nativeWrapper Address of the native token wrapper (optional, defaults to address(0))
  /// @param salt Deployment salt string for deterministic CREATE2 addresses
  struct InfrastructureConfig {
    address accessManagerAdmin;
    address hubConfiguratorAdmin;
    address spokeConfiguratorAdmin;
    address treasurySpokeOwner;
    address spokeProxyAdminOwner;
    address gatewayOwner;
    address nativeWrapper;
    string salt;
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

  function spokeRegistrationExists(string memory json, uint i) internal view returns (bool) {
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

  function nativeTokenKey(string memory json) internal pure returns (string memory) {
    return json.readString('.periphery.nativeTokenKey');
  }

  // ==================== Infrastructure Reader ====================

  function readInfrastructure(
    string memory json
  ) internal view returns (InfrastructureConfig memory) {
    string memory base = '.infrastructure';
    return
      InfrastructureConfig({
        accessManagerAdmin: json.readAddress(string.concat(base, '.accessManagerAdmin')),
        hubConfiguratorAdmin: json.readAddress(string.concat(base, '.hubConfiguratorAdmin')),
        spokeConfiguratorAdmin: json.readAddress(string.concat(base, '.spokeConfiguratorAdmin')),
        treasurySpokeOwner: json.readAddress(string.concat(base, '.treasurySpokeOwner')),
        spokeProxyAdminOwner: json.readAddress(string.concat(base, '.spokeProxyAdminOwner')),
        gatewayOwner: json.readAddressOr(string.concat(base, '.gatewayOwner'), address(0)),
        nativeWrapper: json.readAddressOr(string.concat(base, '.nativeWrapper'), address(0)),
        salt: json.readString(string.concat(base, '.salt'))
      });
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

  function readSpokeRegistration(
    string memory json,
    uint i
  ) internal view returns (SpokeRegistrationConfig memory) {
    return _readSpokeRegistration(json, i, false);
  }

  function readSpokeRegistrationStrict(
    string memory json,
    uint i
  ) internal view returns (SpokeRegistrationConfig memory) {
    return _readSpokeRegistration(json, i, true);
  }

  function _readSpokeRegistration(
    string memory json,
    uint i,
    bool strict
  ) private view returns (SpokeRegistrationConfig memory) {
    string memory base = string.concat('.spokeRegistrations[', vm.toString(i), ']');
    return
      SpokeRegistrationConfig({
        assetKey: json.readString(string.concat(base, '.assetKey')),
        hubKey: json.readString(string.concat(base, '.hubKey')),
        spokeKey: json.readString(string.concat(base, '.spokeKey')),
        addCap: json.readUint(string.concat(base, '.addCap')).toUint40(),
        drawCap: json.readUint(string.concat(base, '.drawCap')).toUint40(),
        riskPremiumThreshold: _resolveUint(
          json,
          string.concat(base, '.riskPremiumThreshold'),
          '.defaults.spokeRegistration.riskPremiumThreshold',
          DEFAULT_SPOKE_REGISTRATION_RISK_PREMIUM_THRESHOLD,
          strict
        ).toUint24(),
        active: _resolveBool(
          json,
          string.concat(base, '.active'),
          '.defaults.spokeRegistration.active',
          DEFAULT_SPOKE_REGISTRATION_ACTIVE,
          strict
        ),
        halted: _resolveBool(
          json,
          string.concat(base, '.halted'),
          '.defaults.spokeRegistration.halted',
          DEFAULT_SPOKE_REGISTRATION_HALTED,
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

  /// @notice Trims the last n bytes from a string. Reverts if n >= string length.
  function trimEnd(string memory str, uint n) internal pure returns (string memory) {
    bytes memory b = bytes(str);
    require(b.length > n);
    bytes memory result = new bytes(b.length - n);
    for (uint j; j < result.length; j++) {
      result[j] = b[j];
    }
    return string(result);
  }
}
