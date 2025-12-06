// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {IProgressLogger} from 'src/deployments/utils/interfaces/IProgressLogger.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {DeployUtils} from 'src/deployments/utils/DeployUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

contract AaveV4DeployBatchScript is Script, DeployUtils, InputUtils {
  string internal constant INPUT_PATH = 'scripts/deploy/inputs/AaveV4DeployInput.json';
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal constant OUTPUT_FILE = 'AaveV4DeployBatch.json';

  constructor() {}

  function run() external {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);
    FullDeployInputs memory inputs = loadFullDeployInputs(INPUT_PATH);

    logger.log('...Starting Aave V4 Batch Deployment...');
    address deployer = msg.sender;
    vm.startBroadcast(deployer);
    OrchestrationReports.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(
        IProgressLogger(address(logger)),
        deployer,
        inputs.admin,
        inputs.nativeWrapperAddress,
        inputs.hubLabels,
        inputs.spokeLabels,
        inputs.setRoles
      );
    vm.stopBroadcast();
    logger.writeJsonReportMarket(report);
    logger.log('...Batch Deployment Completed...');
    logger.log('...Saving Logs...');
    logger.save({fileName: OUTPUT_FILE, withTimestamp: true});
  }
}
