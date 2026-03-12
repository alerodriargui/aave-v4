// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ScriptUtils} from '../ScriptUtils.sol';

// ==================== Sub-Report Structs ====================

struct TokenReport {
  string key;
  address token;
  address priceFeed;
}

struct HubReport {
  string key;
  address hub;
  address treasury;
  address irStrategy;
}

struct SpokeReport {
  string key;
  address spoke;
  address oracle;
}

struct TokenizationReport {
  string key;
  address spoke;
}

// ==================== Top-Level Report ====================

struct DeployReport {
  address admin;
  address accessManager;
  address signatureGateway;
  address nativeTokenGateway;
  address giverPositionManager;
  address takerPositionManager;
  address configPositionManager;
  address hubConfigurator;
  address spokeConfigurator;
  string commit;
  HubReport[] hubs;
  SpokeReport[] spokes;
  TokenReport[] tokens;
  TokenizationReport[] tokenized;
}

/// @title DeployReportLib
/// @notice Finder helpers and push methods for DeployReport storage references.
///         All finders revert with descriptive messages on miss.
library DeployReportLib {
  // ==================== Hub ====================

  function findHub(
    DeployReport storage self,
    string memory key
  ) internal view returns (HubReport storage) {
    for (uint256 i; i < self.hubs.length; ++i) {
      if (ScriptUtils.strEq(self.hubs[i].key, key)) return self.hubs[i];
    }
    revert(string.concat('hub not found: ', key));
  }

  function hubAddress(DeployReport storage self, string memory key) internal view returns (IHub) {
    return IHub(findHub(self, key).hub);
  }

  function pushHub(
    DeployReport storage self,
    string memory key,
    address hub,
    address treasury,
    address irStrategy
  ) internal {
    self.hubs.push(HubReport(key, hub, treasury, irStrategy));
  }

  // ==================== Spoke ====================

  function findSpoke(
    DeployReport storage self,
    string memory key
  ) internal view returns (SpokeReport storage) {
    for (uint256 i; i < self.spokes.length; ++i) {
      if (ScriptUtils.strEq(self.spokes[i].key, key)) return self.spokes[i];
    }
    revert(string.concat('spoke not found: ', key));
  }

  function spokeAddress(
    DeployReport storage self,
    string memory key
  ) internal view returns (ISpoke) {
    return ISpoke(findSpoke(self, key).spoke);
  }

  function pushSpoke(
    DeployReport storage self,
    string memory key,
    address spoke,
    address oracle
  ) internal {
    self.spokes.push(SpokeReport(key, spoke, oracle));
  }

  // ==================== Token ====================

  function findToken(
    DeployReport storage self,
    string memory key
  ) internal view returns (TokenReport storage) {
    for (uint256 i; i < self.tokens.length; ++i) {
      if (ScriptUtils.strEq(self.tokens[i].key, key)) return self.tokens[i];
    }
    revert(string.concat('token not found: ', key));
  }

  function pushToken(
    DeployReport storage self,
    string memory key,
    address token,
    address priceFeed
  ) internal {
    self.tokens.push(TokenReport(key, token, priceFeed));
  }

  // ==================== Tokenization ====================

  function findTokenized(
    DeployReport storage self,
    string memory key
  ) internal view returns (TokenizationReport storage) {
    for (uint256 i; i < self.tokenized.length; ++i) {
      if (ScriptUtils.strEq(self.tokenized[i].key, key)) return self.tokenized[i];
    }
    revert(string.concat('tokenized not found: ', key));
  }

  function pushTokenized(DeployReport storage self, string memory key, address spoke) internal {
    self.tokenized.push(TokenizationReport(key, spoke));
  }

  // ==================== Derived Lookups ====================

  /// @notice Find the assetId for a token on a hub by key-based lookup + linear scan.
  /// @dev Does not work if same token listed multiple times on same hub.
  function assetId(
    DeployReport storage self,
    string memory hubKey,
    string memory tokenKey
  ) internal view returns (uint256) {
    return ScriptUtils.assetId(hubAddress(self, hubKey), findToken(self, tokenKey).token);
  }
}
