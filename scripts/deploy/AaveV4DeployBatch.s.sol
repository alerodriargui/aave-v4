// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {IProgressLogger} from 'src/deployments/utils/interfaces/IProgressLogger.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {DeployUtils} from 'src/deployments/utils/DeployUtils.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

import {
  AaveV4DeployOrchestration
} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';

contract AaveV4DeployBatchScript is Script, DeployUtils, InputUtils {
  string internal constant INPUT_PATH = 'scripts/deploy/inputs/AaveV4DeployInput.toml';
  string internal constant OUTPUT_DIR = 'output/reports/deployments/';
  string internal constant OUTPUT_FILE = 'AaveV4DeployBatch.json';

  constructor() {}

  function run() external {
    OrchestrationReports.FullDeploymentReport memory report;

    vm.createDir(OUTPUT_DIR, true);
    Logger logger = new Logger(string.concat(OUTPUT_DIR, OUTPUT_FILE));
    FullDeployInputs memory inputs = loadFullDeployInputs(INPUT_PATH);

    address deployer = msg.sender;

    logger.log('...Starting Aave V4 Batch Deployment...');

    report = AaveV4DeployOrchestration.deployAaveV4(
      IProgressLogger(address(logger)),
      deployer,
      inputs.admin,
      inputs.nativeWrapperAddress,
      inputs.hubLabels,
      inputs.spokeLabels,
      inputs.setRoles
    );

    writeJsonReportMarket(logger, report);

    logger.log('...Batch Deployment Completed...');
    logger.log('...Saving Logs...');
    logger.save();
  }

  function writeJsonReportMarket(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report
  ) public {
    logger.write('AccessBatchReport', report.accessBatchReport.accessManagerAddress);
    logger.write('HubConfigurator', report.configuratorBatchReport.hubConfiguratorAddress);
    logger.write('SpokeConfigurator', report.configuratorBatchReport.spokeConfiguratorAddress);

    for (uint256 i; i < report.hubBatchReports.length; i++) {
      Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](3);
      hubEntries[0] = Logger.AddressEntry({
        label: 'Hub',
        value: report.hubBatchReports[i].report.hubAddress
      });
      hubEntries[1] = Logger.AddressEntry({
        label: 'InterestRateStrategy',
        value: report.hubBatchReports[i].report.hubAddress
      });
      hubEntries[2] = Logger.AddressEntry({
        label: 'TreasurySpoke',
        value: report.hubBatchReports[i].report.treasurySpokeAddress
      });
      logger.writeGroup(report.hubBatchReports[i].label, hubEntries);
    }

    for (uint256 i; i < report.spokeInstanceBatchReports.length; i++) {
      Logger.AddressEntry[] memory spokeInstanceEntries = new Logger.AddressEntry[](3);
      spokeInstanceEntries[0] = Logger.AddressEntry({
        label: 'SpokeInstance Proxy',
        value: report.spokeInstanceBatchReports[i].report.spokeProxyAddress
      });
      spokeInstanceEntries[1] = Logger.AddressEntry({
        label: 'SpokeInstance Implementation',
        value: report.spokeInstanceBatchReports[i].report.spokeImplementationAddress
      });
      spokeInstanceEntries[2] = Logger.AddressEntry({
        label: 'AaveOracle',
        value: report.spokeInstanceBatchReports[i].report.aaveOracleAddress
      });
      logger.writeGroup(report.spokeInstanceBatchReports[i].label, spokeInstanceEntries);
    }

    logger.write('SignatureGateway', report.gatewaysBatchReport.signatureGatewayAddress);
    logger.write('NativeTokenGateway', report.gatewaysBatchReport.nativeGatewayAddress);
  }
}
