// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

import {Script} from 'forge-std/Script.sol';

abstract contract AaveV4DeployBatchBaseScript is Script, InputUtils {
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
    FullDeployInputs memory inputs = loadFullDeployInputs(
      string.concat(INPUT_PATH, _inputFileName)
    );
    (, address deployer, ) = vm.readCallers();
    inputs = _loadWarningsAndSanitizeInputs(logger, inputs, deployer);

    logger.log('CHAIN ID', block.chainid);
    logger.log('...Starting Aave V4 Batch Deployment...');
    vm.startBroadcast(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(logger, deployer, inputs);
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
    if (inputs.grantRoles) {
      _logAndAppend(logger, string.concat('Roles are being set'));
      hadWarnings = true;
      if (inputs.accessManagerAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Access Manager Admin', message, outcome));
        sanitizedInputs.accessManagerAdmin = deployer;
      }
      if (inputs.hubConfiguratorOwner == address(0)) {
        _logAndAppend(logger, string.concat('Hub Configurator Owner', message, outcome));
        sanitizedInputs.hubConfiguratorOwner = deployer;
      }
      if (inputs.spokeConfiguratorOwner == address(0)) {
        _logAndAppend(logger, string.concat('Spoke Configurator Owner', message, outcome));
        sanitizedInputs.spokeConfiguratorOwner = deployer;
      }
      if (inputs.spokeProxyAdminOwner == address(0)) {
        _logAndAppend(logger, string.concat('Spoke Proxy Admin Owner', message, outcome));
        sanitizedInputs.spokeProxyAdminOwner = deployer;
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        _logAndAppend(logger, string.concat('Treasury Spoke Owner', message, outcome));
        sanitizedInputs.treasurySpokeOwner = deployer;
      }
      if (inputs.spokeAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Spoke Admin', message, outcome));
        sanitizedInputs.spokeAdmin = deployer;
      }
      if (inputs.hubAdmin == address(0)) {
        _logAndAppend(logger, string.concat('Hub Admin', message, outcome));
        sanitizedInputs.hubAdmin = deployer;
      }
    }
    if (inputs.hubLabels.length == 0) {
      _logAndAppend(logger, string.concat('Hub will not be deployed'));
      hadWarnings = true;
      sanitizedInputs.hubLabels = new string[](0);
    }
    if (inputs.spokeLabels.length == 0) {
      _logAndAppend(logger, string.concat('Spoke will not be deployed'));
      hadWarnings = true;
      sanitizedInputs.spokeLabels = new string[](0);
    }
    if (inputs.nativeWrapper == address(0)) {
      _logAndAppend(
        logger,
        string.concat(
          'Native wrapper',
          message,
          "; NativeTokenGateway & SignatureGateway will not be deployed'"
        )
      );
      hadWarnings = true;
      sanitizedInputs.nativeWrapper = address(0);
    }
    if (inputs.gatewayOwner == address(0)) {
      _logAndAppend(logger, string.concat('Gateway owner', message, outcome));
      hadWarnings = true;
      sanitizedInputs.gatewayOwner = deployer;
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
