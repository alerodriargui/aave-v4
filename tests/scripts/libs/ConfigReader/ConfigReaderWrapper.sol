// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title ConfigReaderWrapper
/// @notice Thin wrapper contract around the ConfigReader library for testing.
///         Exposes all library functions as external calls so they can be tested
///         directly, including fuzz testing with dynamic JSON inputs.
contract ConfigReaderWrapper {
  using ConfigReader for string;

  // ==================== Existence Checks ====================

  function hubExists(string memory json, uint256 i) external view returns (bool) {
    return json.hubExists(i);
  }

  function spokeExists(string memory json, uint256 i) external view returns (bool) {
    return json.spokeExists(i);
  }

  function assetExists(string memory json, uint256 i) external view returns (bool) {
    return json.assetExists(i);
  }

  function spokeRegistrationExists(string memory json, uint256 i) external view returns (bool) {
    return json.spokeRegistrationExists(i);
  }

  function reserveExists(string memory json, uint256 i) external view returns (bool) {
    return json.reserveExists(i);
  }

  // ==================== Simple Accessors ====================

  function hubKey(string memory json, uint256 i) external pure returns (string memory) {
    return json.hubKey(i);
  }

  function spokeKey(string memory json, uint256 i) external pure returns (string memory) {
    return json.spokeKey(i);
  }

  function tokenKeys(string memory json) external pure returns (string[] memory) {
    return json.tokenKeys();
  }

  function tokenAddress(string memory json, string memory key) external pure returns (address) {
    return json.tokenAddress(key);
  }

  function tokenPriceFeed(string memory json, string memory key) external view returns (address) {
    return json.tokenPriceFeed(key);
  }

  // ==================== Readers ====================

  function readInfrastructure(
    string memory json
  ) external view returns (ConfigReader.InfrastructureConfig memory) {
    return json.readInfrastructure();
  }

  function readAsset(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.AssetConfig memory) {
    return json.readAsset(i);
  }

  function readAssetStrict(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.AssetConfig memory) {
    return json.readAssetStrict(i);
  }

  function readSpoke(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.SpokeDeployConfig memory) {
    return json.readSpoke(i);
  }

  function readSpokeStrict(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.SpokeDeployConfig memory) {
    return json.readSpokeStrict(i);
  }

  function readSpokeRegistration(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.SpokeRegistrationConfig memory) {
    return json.readSpokeRegistration(i);
  }

  function readSpokeRegistrationStrict(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.SpokeRegistrationConfig memory) {
    return json.readSpokeRegistrationStrict(i);
  }

  function readReserve(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.ReserveConfig memory) {
    return json.readReserve(i);
  }

  function readReserveStrict(
    string memory json,
    uint256 i
  ) external view returns (ConfigReader.ReserveConfig memory) {
    return json.readReserveStrict(i);
  }

  function readLiquidationConfig(
    string memory json,
    uint256 i
  ) external view returns (ISpoke.LiquidationConfig memory) {
    return json.readLiquidationConfig(i);
  }

  function readLiquidationConfigStrict(
    string memory json,
    uint256 i
  ) external view returns (ISpoke.LiquidationConfig memory) {
    return json.readLiquidationConfigStrict(i);
  }

  // ==================== Periphery ====================

  function deploySignatureGateway(string memory json) external view returns (bool) {
    return json.deploySignatureGateway();
  }

  function deployNativeTokenGateway(string memory json) external view returns (bool) {
    return json.deployNativeTokenGateway();
  }

  function nativeTokenKey(string memory json) external pure returns (string memory) {
    return json.nativeTokenKey();
  }

  // ==================== Utilities ====================

  function trimEnd(string memory str, uint256 n) external pure returns (string memory) {
    return ConfigReader.trimEnd(str, n);
  }
}
