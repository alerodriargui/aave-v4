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
  string internal constant INPUT_PATH = 'scripts/deploy/inputs/';
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';

  string internal _inputFileName;
  string internal _outputFileName;

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
    _loadWarnings(logger, inputs);
    inputs = _sanitizeInputs(inputs, deployer);

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

  function _loadWarnings(MetadataLogger logger, FullDeployInputs memory inputs) internal virtual {
    bool hadWarnings = false;
    string memory warnings = '';
    if (inputs.grantRoles) {
      warnings = _logAndAppend(logger, warnings, 'WARNING: Roles are being set');
      hadWarnings = true;
      if (inputs.accessManagerAdmin == address(0)) {
        warnings = _logAndAppend(
          logger,
          warnings,
          'WARNING: Access Manager Admin is zero address; role will be granted to deployer by default'
        );
      }
      if (inputs.hubConfiguratorOwner == address(0)) {
        warnings = _logAndAppend(
          logger,
          warnings,
          'WARNING: Hub Configurator Owner is zero address; role will be granted to deployer by default'
        );
      }
      if (inputs.spokeConfiguratorOwner == address(0)) {
        warnings = _logAndAppend(
          logger,
          warnings,
          'WARNING: Spoke Configurator Owner is zero address; role will be granted to deployer by default'
        );
      }
      if (inputs.spokeProxyAdminOwner == address(0)) {
        warnings = _logAndAppend(
          logger,
          warnings,
          'WARNING: Spoke Proxy Admin Owner is zero address; role will be granted to deployer by default'
        );
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        warnings = _logAndAppend(
          logger,
          warnings,
          'WARNING: Treasury Spoke Owner is zero address; role will be granted to deployer by default'
        );
      }
      if (inputs.spokeAdmin == address(0)) {
        warnings = _logAndAppend(
          logger,
          warnings,
          'WARNING: Spoke Admin is zero address; spoke admin roles will be granted to deployer by default'
        );
      }
    }
    if (inputs.hubLabels.length == 0) {
      warnings = _logAndAppend(logger, warnings, 'WARNING: Hub will not be deployed');
      hadWarnings = true;
    }
    if (inputs.spokeLabels.length == 0) {
      warnings = _logAndAppend(logger, warnings, 'WARNING: Spoke will not be deployed');
      hadWarnings = true;
    }
    if (inputs.nativeWrapper == address(0)) {
      warnings = _logAndAppend(
        logger,
        warnings,
        'WARNING: Native wrapper zero address; NativeTokenGateway & SignatureGateway will not be deployed'
      );
      hadWarnings = true;
    }
    logger.log('');

    if (hadWarnings) {
      _executeUserPrompt(warnings);
    }
  }

  function _executeUserPrompt(string memory warnings) internal virtual {
    string memory ack = vm.prompt(string.concat(warnings, "\nEnter 'y' to continue"));
    if (keccak256(bytes(ack)) != keccak256(bytes('y'))) {
      revert('User did not acknowledge warnings. Please try again.');
    }
  }

  function _sanitizeInputs(
    FullDeployInputs memory deployInputs,
    address deployer
  ) internal view virtual returns (FullDeployInputs memory) {
    // if any admin is zero address, default to deployer as admin
    InputUtils.FullDeployInputs memory sanitizedInputs = deployInputs;
    sanitizedInputs.accessManagerAdmin = deployInputs.accessManagerAdmin != address(0)
      ? deployInputs.accessManagerAdmin
      : deployer;
    sanitizedInputs.hubConfiguratorOwner = deployInputs.hubConfiguratorOwner != address(0)
      ? deployInputs.hubConfiguratorOwner
      : deployer;
    sanitizedInputs.treasurySpokeOwner = deployInputs.treasurySpokeOwner != address(0)
      ? deployInputs.treasurySpokeOwner
      : deployer;
    sanitizedInputs.spokeProxyAdminOwner = deployInputs.spokeProxyAdminOwner != address(0)
      ? deployInputs.spokeProxyAdminOwner
      : deployer;
    sanitizedInputs.spokeConfiguratorOwner = deployInputs.spokeConfiguratorOwner != address(0)
      ? deployInputs.spokeConfiguratorOwner
      : deployer;
    sanitizedInputs.gatewayOwner = deployInputs.gatewayOwner != address(0)
      ? deployInputs.gatewayOwner
      : deployer;

    return sanitizedInputs;
  }

  function _logAndAppend(
    MetadataLogger logger,
    string memory warnings,
    string memory warning
  ) internal virtual returns (string memory) {
    logger.log(warning);
    return string.concat(warnings, warning, '\n');
  }
}
