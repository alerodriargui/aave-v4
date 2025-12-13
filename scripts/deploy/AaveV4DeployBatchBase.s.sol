// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {DeployUtils} from 'src/deployments/utils/DeployUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

import {console2 as console} from 'forge-std/console2.sol';

abstract contract AaveV4DeployBatchBaseScript is Script, DeployUtils, InputUtils {
  string internal constant INPUT_PATH = 'scripts/deploy/inputs/';
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';

  string internal _inputFileName;
  string internal _outputFileName;

  constructor(string memory inputFileName_, string memory outputFileName_) {
    _inputFileName = inputFileName_;
    _outputFileName = outputFileName_;
  }

  function run() external {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    FullDeployInputs memory inputs = loadFullDeployInputs(
      string.concat(INPUT_PATH, _inputFileName)
    );

    _loadWarnings(logger, inputs);

    logger.log('...Starting Aave V4 Batch Deployment...');
    address deployer = msg.sender;
    vm.startBroadcast(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4({logger: logger, deployer: deployer, deployInputs: inputs});
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
      logger.log('WARNING: Roles are being set');
      warnings = string.concat(warnings, 'WARNING: Roles are being set\n');
      hadWarnings = true;
      if (inputs.accessManagerAdmin == address(0)) {
        logger.log(
          'WARNING: Access Manager Admin is zero address; role will be granted to deployer by default'
        );
        warnings = string.concat(
          warnings,
          'WARNING: Access Manager Admin is zero address; role will be granted to deployer by default\n'
        );
      }
      if (inputs.hubConfiguratorOwner == address(0)) {
        logger.log(
          'WARNING: Hub Configurator Owner is zero address; role will be granted to deployer by default'
        );
        warnings = string.concat(
          warnings,
          'WARNING: Hub Configurator Owner is zero address; role will be granted to deployer by default\n'
        );
      }
      if (inputs.spokeConfiguratorOwner == address(0)) {
        logger.log(
          'WARNING: Spoke Configurator Owner is zero address; role will be granted to deployer by default'
        );
        warnings = string.concat(
          warnings,
          'WARNING: Spoke Configurator Owner is zero address; role will be granted to deployer by default\n'
        );
      }
      if (inputs.spokeProxyAdminOwner == address(0)) {
        logger.log(
          'WARNING: Spoke Proxy Admin Owner is zero address; role will be granted to deployer by default'
        );
        warnings = string.concat(
          warnings,
          'WARNING: Spoke Proxy Admin Owner is zero address; role will be granted to deployer by default\n'
        );
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        logger.log(
          'WARNING: Treasury Spoke Owner is zero address; role will be granted to deployer by default'
        );
        warnings = string.concat(
          warnings,
          'WARNING: Treasury Spoke Owner is zero address; role will be granted to deployer by default\n'
        );
      }
      if (inputs.spokeAdmin == address(0)) {
        logger.log(
          'WARNING: Spoke Admin is zero address; role will be granted to deployer by default'
        );
        warnings = string.concat(
          warnings,
          'WARNING: Spoke Admin is zero address; spoke admin roles will be granted to deployer by default\n'
        );
      }
    }
    if (inputs.hubLabels.length == 0) {
      logger.log('WARNING: Hub will not be deployed');
      hadWarnings = true;
      warnings = string.concat(warnings, 'WARNING: Hub will not be deployed\n');
    }
    if (inputs.spokeLabels.length == 0) {
      logger.log('WARNING: Spoke will not be deployed');
      hadWarnings = true;
      warnings = string.concat(warnings, 'WARNING: Spoke will not be deployed\n');
    }
    if (inputs.nativeWrapperAddress == address(0)) {
      logger.log('WARNING: Native wrapper zero address; NativeTokenGateway will not be deployed');
      hadWarnings = true;
      warnings = string.concat(
        warnings,
        'WARNING: Native wrapper zero address; NativeTokenGateway will not be deployed\n'
      );
    }
    logger.log('');

    if (hadWarnings) {
      string memory ack = vm.prompt(string.concat(warnings, "\nEnter 'y' to continue"));
      if (keccak256(bytes(ack)) != keccak256(bytes('y'))) {
        revert('User did not acknowledge warnings. Please try again.');
      }
    }
  }
}
