// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {DeployUtils} from 'src/deployments/utils/DeployUtils.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

contract AaveV4DeployBatchScript is Script, DeployUtils, InputUtils {
  string internal constant INPUT_PATH = 'src/deployments/inputs/AaveV4DeployInput.toml';
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal constant OUTPUT_FILE = 'AaveV4DeployBatch.json';

  constructor() {}

  function run() external {
    vm.createDir(OUTPUT_DIR, true);
    Logger logger = new Logger(string.concat(OUTPUT_DIR, OUTPUT_FILE));
    FullDeployInputs memory inputs = loadFullDeployInputs(INPUT_PATH);

    address deployer = msg.sender;

    logger.log('Starting Aave V4 Batch Deployment');
    logger.log('deployer', deployer);

    vm.startBroadcast();
    AaveV4DeployOrchestration.deployAaveV4(
      logger,
      deployer,
      inputs.admin,
      inputs.nativeWrapperAddress,
      inputs.hubLabels,
      inputs.spokeLabels,
      inputs.setRoles
    );
    vm.stopBroadcast();

    logger.log('Batch Deployment Completed');
    logger.log('Saving Logs');
    logger.save();
  }
}
