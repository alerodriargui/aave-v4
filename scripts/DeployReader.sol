// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {stdJson} from 'forge-std/StdJson.sol';

/// @title DeployReader
/// @notice Library for reading deployed addresses from output/deploy.json via stdJson.
library DeployReader {
  using stdJson for string;

  // ==================== Scalar Addresses ====================

  function admin(string memory json) internal pure returns (address) {
    return json.readAddress('.admin');
  }

  function accessManager(string memory json) internal pure returns (address) {
    return json.readAddress('.accessManager');
  }

  function signatureGateway(string memory json) internal pure returns (address) {
    return json.readAddress('.signatureGateway');
  }

  function nativeTokenGateway(string memory json) internal pure returns (address) {
    return json.readAddress('.nativeTokenGateway');
  }

  function giverPositionManager(string memory json) internal view returns (address) {
    return json.readAddressOr('.giverPositionManager', address(0));
  }

  function takerPositionManager(string memory json) internal view returns (address) {
    return json.readAddressOr('.takerPositionManager', address(0));
  }

  function configPositionManager(string memory json) internal view returns (address) {
    return json.readAddressOr('.configPositionManager', address(0));
  }

  function hubConfigurator(string memory json) internal pure returns (address) {
    return json.readAddress('.hubConfigurator');
  }

  function spokeConfigurator(string memory json) internal pure returns (address) {
    return json.readAddress('.spokeConfigurator');
  }

  // ==================== Keyed Addresses ====================

  function hub(string memory json, string memory hubKey) internal pure returns (address) {
    return json.readAddress(string.concat('.hub.', hubKey));
  }

  function irStrategy(string memory json, string memory hubKey) internal pure returns (address) {
    return json.readAddress(string.concat('.irStrategy.', hubKey));
  }

  function treasury(string memory json, string memory hubKey) internal pure returns (address) {
    return json.readAddress(string.concat('.treasury.', hubKey));
  }

  function spoke(string memory json, string memory spokeKey) internal pure returns (address) {
    return json.readAddress(string.concat('.spoke.', spokeKey));
  }

  function oracle(string memory json, string memory spokeKey) internal pure returns (address) {
    return json.readAddress(string.concat('.oracle.', spokeKey));
  }

  function token(string memory json, string memory tokenKey) internal pure returns (address) {
    return json.readAddress(string.concat('.token.', tokenKey));
  }

  function tokenized(string memory json, string memory tsKey) internal pure returns (address) {
    return json.readAddress(string.concat('.tokenized.', tsKey));
  }
}
