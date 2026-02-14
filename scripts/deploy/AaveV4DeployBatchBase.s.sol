// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

import {Script} from 'forge-std/Script.sol';

// solhint-disable quotes
abstract contract AaveV4DeployBatchBaseScript is Script, InputUtils {
  using ConfigReader for string;

  struct Warnings {
    string[] s;
  }

  string internal constant INPUT_PATH = 'config/';
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal _inputFileName;
  string internal _outputFileName;
  Warnings internal _warnings;

  constructor(string memory inputFileName_, string memory outputFileName_) {
    _inputFileName = inputFileName_;
    _outputFileName = outputFileName_;
  }

  function run() external virtual {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);

    string memory json = vm.readFile(string.concat(INPUT_PATH, _inputFileName));
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();
    (, address deployer, ) = vm.readCallers();

    uint256 hubCount;
    while (json.hubExists(hubCount)) hubCount++;
    uint256 spokeCount;
    while (json.spokeExists(spokeCount)) spokeCount++;

    FullDeployInputs memory inputs = _buildDeployInputs(json, infra, hubCount, spokeCount, true);
    inputs = _loadWarningsAndSanitizeInputs(logger, inputs, deployer);

    logger.log('CHAIN ID', block.chainid);
    logger.log('...Starting Aave V4 Batch Deployment...');
    vm.startBroadcast(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(logger, deployer, inputs, _getHubBytecode(), _getSpokeBytecode());
    vm.stopBroadcast();
    logger.writeJsonReportMarket(report);
    logger.log('...Batch Deployment Completed...');
    logger.log('...Saving Logs...');
    logger.save({fileName: _outputFileName, withTimestamp: true});
  }

  function _loadWarningsAndSanitizeInputs(
    MetadataLogger logger,
    FullDeployInputs memory inputs,
    address deployer
  ) internal virtual returns (FullDeployInputs memory) {
    string memory message = ' is zero address';
    string memory outcome = '; defaulting to deployer';

    FullDeployInputs memory sanitizedInputs = inputs;
    bool hadWarnings = false;

    // ==================== Deployment Summary ====================
    logger.log('========== DEPLOYMENT SUMMARY ==========');

    // Hubs
    if (inputs.hubLabels.length > 0) {
      logger.log(string.concat('Hubs to deploy: ', vm.toString(inputs.hubLabels.length)));
      for (uint256 i; i < inputs.hubLabels.length; i++) {
        logger.log(string.concat('  - ', inputs.hubLabels[i]));
      }
    } else {
      _logAndAppend(logger, 'No hubs will be deployed');
      hadWarnings = true;
    }

    // Spokes
    if (inputs.spokeLabels.length > 0) {
      logger.log(string.concat('Spokes to deploy: ', vm.toString(inputs.spokeLabels.length)));
      for (uint256 i; i < inputs.spokeLabels.length; i++) {
        logger.log(string.concat('  - ', inputs.spokeLabels[i]));
        // Flag default values on per-spoke config
        if (inputs.spokeMaxReservesLimits[i] == ConfigReader.DEFAULT_MAX_USER_RESERVES_LIMIT) {
          _logAndAppend(
            logger,
            string.concat(inputs.spokeLabels[i], ': maxUserReservesLimit using default (128)')
          );
          hadWarnings = true;
        }
        if (inputs.spokeOracleDecimals[i] == ConfigReader.DEFAULT_ORACLE_DECIMALS) {
          _logAndAppend(
            logger,
            string.concat(inputs.spokeLabels[i], ': oracleDecimals using default (8)')
          );
          hadWarnings = true;
        }
        if (
          keccak256(bytes(inputs.spokeOracleDescriptions[i])) ==
          keccak256(bytes(string.concat(inputs.spokeLabels[i], ConfigReader.DEFAULT_ORACLE_SUFFIX)))
        ) {
          _logAndAppend(
            logger,
            string.concat(inputs.spokeLabels[i], ': oracleSuffix using default " (USD)"')
          );
          hadWarnings = true;
        }
      }
    } else {
      _logAndAppend(logger, 'No spokes will be deployed');
      hadWarnings = true;
    }

    // NativeTokenGateway
    if (inputs.deployNativeTokenGateway) {
      if (inputs.nativeWrapper == address(0)) {
        _logAndAppend(logger, 'deployNativeTokenGateway is true but nativeWrapper is zero address');
        hadWarnings = true;
      } else {
        logger.log('NativeTokenGateway will be deployed');
      }
    } else {
      logger.log('NativeTokenGateway: skipped (deployNativeTokenGateway is false)');
    }

    // SignatureGateway
    if (inputs.deploySignatureGateway) {
      logger.log('SignatureGateway will be deployed');
    } else {
      logger.log('SignatureGateway: skipped (deploySignatureGateway is false)');
    }

    // Roles
    if (inputs.grantRoles) {
      logger.log('Roles: will be granted during deployment');
    } else {
      logger.log('Roles: deferred (not granted during deployment)');
    }

    logger.log('========================================');

    // ==================== Zero Address Sanitization ====================
    if (inputs.grantRoles) {
      if (inputs.accessManagerAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Access Manager Admin', message, outcome));
        sanitizedInputs.accessManagerAdmin = deployer;
        hadWarnings = true;
      }
      if (inputs.hubConfiguratorAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Hub Configurator Admin', message, outcome));
        sanitizedInputs.hubConfiguratorAdmin = deployer;
        hadWarnings = true;
      }
      if (inputs.spokeConfiguratorAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Spoke Configurator Admin', message, outcome));
        sanitizedInputs.spokeConfiguratorAdmin = deployer;
        hadWarnings = true;
      }
      if (inputs.spokeProxyAdminOwner == address(0)) {
        _logAndAppend(logger, string.concat('Spoke Proxy Admin Owner', message, outcome));
        sanitizedInputs.spokeProxyAdminOwner = deployer;
        hadWarnings = true;
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        _logAndAppend(logger, string.concat('Treasury Spoke Owner', message, outcome));
        sanitizedInputs.treasurySpokeOwner = deployer;
        hadWarnings = true;
      }
      if (inputs.spokeAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Spoke Admin', message, outcome));
        sanitizedInputs.spokeAdmin = deployer;
        hadWarnings = true;
      }
      if (inputs.hubAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Hub Admin', message, outcome));
        sanitizedInputs.hubAdmin = deployer;
        hadWarnings = true;
      }
    }
    if (inputs.gatewayOwner == address(0)) {
      _logAndAppend(logger, string.concat('Gateway owner', message, outcome));
      sanitizedInputs.gatewayOwner = deployer;
      hadWarnings = true;
    }
    if (hadWarnings) {
      _executeUserPrompt();
    }
    return sanitizedInputs;
  }

  function _executeUserPrompt() internal virtual {
    string memory ack = vm.prompt(
      string.concat(_joinWarnings(_warnings), "\nEnter 'y' to continue")
    );
    if (keccak256(bytes(ack)) != keccak256(bytes('y'))) {
      revert('User did not acknowledge warnings. Please try again.');
    }
  }

  function _getHubBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/Hub.sol:Hub');
  }

  function _getSpokeBytecode() internal view returns (bytes memory) {
    return vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance');
  }

  function _logAndAppend(MetadataLogger logger, string memory warning) internal virtual {
    warning = string.concat('WARNING: ', warning);
    logger.log(warning);
    _warnings.s.push(warning);
  }

  function _joinWarnings(Warnings storage warnings) internal view virtual returns (string memory) {
    uint256 n = warnings.s.length;
    if (n == 0) return '';
    string memory out = warnings.s[0];
    for (uint256 i = 1; i < n; i++) {
      out = string.concat(out, '\n', warnings.s[i]);
    }
    return string.concat(out, '\n');
  }
}
