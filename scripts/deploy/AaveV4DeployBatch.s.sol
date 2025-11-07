// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {DeployUtils} from 'src/deployments/utils/DeployUtils.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

import {BatchReports} from 'src/deployments/types/BatchReports.sol';

import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

contract AaveV4DeployBatchScript is Script, DeployUtils, InputUtils {
  string internal constant INPUT_PATH = 'scripts/deploy/input/AaveV4DeployInput.json';
  string internal constant OUTPUT_PATH = 'output/reports/deployments/AaveV4DeployBatch.json';

  constructor() {}

  function run() external {
    Logger logger = new Logger(OUTPUT_PATH);
    FullDeployInputs memory inputs = loadFullDeployInputs(INPUT_PATH);
    //TODO : load roles

    address deployer = msg.sender;

    logger.log('Starting Aave V4 Batch Deployment');

    vm.startBroadcast();
    AaveV4DeployOrchestration.FullDeploymentReport memory report = AaveV4DeployOrchestration
      .deployAaveV4(
        logger,
        deployer,
        inputs.admin,
        inputs.nativeWrapperAddress,
        inputs.hubLabels,
        inputs.spokeLabels
      );
    vm.stopBroadcast();

    // TODO : apply roles

    logger.log('Batch Deployment Completed');
    logger.log('Saving Logs');
    logger.save();
  }
}
