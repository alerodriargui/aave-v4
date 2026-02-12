// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {stdJson} from 'forge-std/StdJson.sol';
import {ConfigReader} from '../ConfigReader.sol';
import {DeployReader} from '../DeployReader.sol';
import {ScriptUtils} from '../ScriptUtils.sol';
import {DeployReport, DeployReportLib} from './DeployTypes.sol';

/// @title ReportIO
/// @notice Serialize DeployReport to JSON and restore from JSON.
///         Output format matches the existing deploy.json structure.
library ReportIO {
  using stdJson for string;
  using ConfigReader for string;
  using DeployReader for string;
  using DeployReportLib for DeployReport;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // ==================== Write ====================

  /// @notice Serialize DeployReport to JSON and write to outputPath.
  function writeReport(DeployReport storage report, string memory outputPath) internal {
    string memory root = 'root';

    // Hub-keyed objects: hub, irStrategy, treasury
    {
      string memory HUBS;
      string memory IR_STRATEGIES;
      string memory TREASURIES;
      for (uint256 i; i < report.hubs.length; ++i) {
        HUBS = vm.serializeAddress('hub', report.hubs[i].key, report.hubs[i].hub);
        IR_STRATEGIES = vm.serializeAddress('irStrategy', report.hubs[i].key, report.hubs[i].irStrategy);
        TREASURIES = vm.serializeAddress('treasury', report.hubs[i].key, report.hubs[i].treasury);
      }
      vm.serializeString(root, 'hub', HUBS);
      vm.serializeString(root, 'irStrategy', IR_STRATEGIES);
      vm.serializeString(root, 'treasury', TREASURIES);
    }

    // Spoke-keyed objects: spoke, oracle
    {
      string memory SPOKES;
      string memory ORACLES;
      for (uint256 i; i < report.spokes.length; ++i) {
        SPOKES = vm.serializeAddress('spoke', report.spokes[i].key, report.spokes[i].spoke);
        ORACLES = vm.serializeAddress('oracle', report.spokes[i].key, report.spokes[i].oracle);
      }
      vm.serializeString(root, 'spoke', SPOKES);
      vm.serializeString(root, 'oracle', ORACLES);
    }

    // Token-keyed object
    {
      string memory TOKENS;
      for (uint256 i; i < report.tokens.length; ++i) {
        TOKENS = vm.serializeAddress('token', report.tokens[i].key, report.tokens[i].token);
      }
      vm.serializeString(root, 'token', TOKENS);
    }

    // Tokenization-keyed object
    {
      string memory TOKENIZED;
      for (uint256 i; i < report.tokenized.length; ++i) {
        TOKENIZED = vm.serializeAddress('tokenized', report.tokenized[i].key, report.tokenized[i].spoke);
      }
      if (report.tokenized.length > 0) {
        vm.serializeString(root, 'tokenized', TOKENIZED);
      }
    }

    // Scalar fields
    {
      vm.serializeAddress(root, 'admin', report.admin);
      vm.serializeAddress(root, 'accessManager', report.accessManager);
      vm.serializeAddress(root, 'signatureGateway', report.signatureGateway);
      vm.serializeAddress(root, 'nativeTokenGateway', report.nativeTokenGateway);
      vm.serializeAddress(root, 'hubConfigurator', report.hubConfigurator);
      vm.serializeAddress(root, 'spokeConfigurator', report.spokeConfigurator);
    }
    root = vm.serializeString(root, 'commit', report.commit);

    vm.writeJson(root, outputPath);
  }

  // ==================== Read ====================

  /// @notice Read deploy.json + config JSON, populate DeployReport storage.
  ///         Keys come from config JSON. Token priceFeed comes from config JSON.
  function readReport(
    DeployReport storage report,
    string memory deployJsonPath,
    string memory configJson
  ) internal {
    string memory deploy = vm.readFile(deployJsonPath);

    report.admin = deploy.admin();
    report.accessManager = deploy.accessManager();
    vm.label(report.accessManager, 'AccessManager');

    // Hubs
    for (uint256 hi = 0; configJson.hubExists(hi); hi++) {
      string memory key = configJson.hubKey(hi);
      report.pushHub(key, deploy.hub(key), deploy.treasury(key), deploy.irStrategy(key));
      vm.label(deploy.hub(key), key);
    }

    // Spokes
    for (uint256 si = 0; configJson.spokeExists(si); si++) {
      string memory key = configJson.spokeKey(si);
      report.pushSpoke(key, deploy.spoke(key), deploy.oracle(key));
      vm.label(deploy.spoke(key), key);
    }

    // Tokens — priceFeed from config JSON, not deploy.json
    {
      string[] memory keys = configJson.tokenKeys();
      for (uint256 i; i < keys.length; ++i) {
        report.pushToken(keys[i], deploy.token(keys[i]), configJson.tokenPriceFeed(keys[i]));
      }
    }

    // Tokenization spokes
    for (uint256 ai = 0; configJson.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = configJson.readAsset(ai);
      if (asset.tokenizeEnabled) {
        string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4);
        string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);
        report.pushTokenized(tsKey, deploy.tokenized(tsKey));
        vm.label(deploy.tokenized(tsKey), string.concat('TOKENIZED_', tsKey));
      }
    }

    // Scalar fields
    report.signatureGateway = deploy.signatureGateway();
    report.nativeTokenGateway = deploy.nativeTokenGateway();
    report.hubConfigurator = deploy.hubConfigurator();
    report.spokeConfigurator = deploy.spokeConfigurator();
  }
}
