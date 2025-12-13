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

  function _loadWarnings(
    MetadataLogger logger,
    FullDeployInputs memory inputs
  ) internal pure virtual {
    if (inputs.grantRoles) {
      logger.log('WARNING: Roles are being set');
      if (inputs.accessManagerAdmin == address(0)) {
        logger.log(
          'WARNING: Access Manager Admin is zero address; admin roles will be granted to deployer by default'
        );
      }
      if (inputs.hubConfiguratorOwner == address(0)) {
        logger.log(
          'WARNING: Hub Configurator Owner is zero address; configurator roles will be granted to deployer by default'
        );
      }
      if (inputs.spokeConfiguratorOwner == address(0)) {
        logger.log(
          'WARNING: Spoke Configurator Owner is zero address; configurator roles will be granted to deployer by default'
        );
      }
      if (inputs.spokeProxyAdminOwner == address(0)) {
        logger.log(
          'WARNING: Spoke Proxy Admin Owner is zero address; proxy admin roles will be granted to deployer by default'
        );
      }
      if (inputs.treasurySpokeOwner == address(0)) {
        logger.log(
          'WARNING: Treasury Spoke Owner is zero address; treasury spoke roles will be granted to deployer by default'
        );
      }
      if (inputs.spokeAdmin == address(0)) {
        logger.log(
          'WARNING: Spoke Admin is zero address; spoke admin roles will be granted to deployer by default'
        );
      }
    }
    if (inputs.hubLabels.length == 0) {
      logger.log('WARNING: Hub will not be deployed');
    }
    if (inputs.spokeLabels.length == 0) {
      logger.log('WARNING: Spoke will not be deployed');
    }
    if (inputs.nativeWrapperAddress == address(0)) {
      logger.log('WARNING: Native wrapper zero address; NativeTokenGateway will not be deployed');
    }
    logger.log('');
  }
}
