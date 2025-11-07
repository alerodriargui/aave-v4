// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {Logger} from 'src/deployments/utils/Logger.sol';
import {BatchReports} from 'src/deployments/types/BatchReports.sol';
import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4GatewaysBatch} from 'src/deployments/batches/AaveV4GatewaysBatch.sol';

library AaveV4DeployOrchestration {
  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  uint8 constant ORACLE_DECIMALS = 8;
  string constant ORACLE_SUFFIX = ' (USD)';

  struct SpokeDeploymentReport {
    string label;
    BatchReports.SpokeInstanceBatchReport report;
  }

  struct HubDeploymentReport {
    string label;
    BatchReports.HubBatchReport report;
  }

  struct FullDeploymentReport {
    BatchReports.AccessBatchReport accessBatchReport;
    SpokeDeploymentReport spokeInstanceBatchReport;
    HubDeploymentReport hubBatchReport;
    BatchReports.GatewaysBatchReport gatewaysBatchReport;
  }

  function deployAaveV4(
    Logger logger,
    address deployer,
    address admin,
    address nativeWrapper,
    string[] memory hubLabels,
    string[] memory spokeLabels
  ) internal returns (FullDeploymentReport memory) {
    FullDeploymentReport memory report;

    // Deploy Access Batch
    report.accessBatchReport = _deployAccessBatch(admin);
    logger.log('AccessManager', report.accessBatchReport.accessManagerAddress);

    // Deploy Hub Batches
    uint256 hubCount = hubLabels.length;
    Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](hubCount);
    for (uint256 i; i < hubCount; i++) {
      report.hubBatchReport.label = hubLabels[i];
      report.hubBatchReport.report = _deployHubBatch(
        admin,
        report.accessBatchReport.accessManagerAddress
      );
      hubEntries[i] = Logger.AddressEntry({
        label: hubLabels[i],
        value: report.hubBatchReport.report.hubAddress
      });
      logger.log(string.concat(hubLabels[i], ' Hub'), report.hubBatchReport.report.hubAddress);
      logger.log(
        string.concat(hubLabels[i], ' InterestRateStrategy'),
        report.hubBatchReport.report.irStrategyAddress
      );
      logger.log(
        string.concat(hubLabels[i], ' TreasurySpoke'),
        report.hubBatchReport.report.treasurySpokeAddress
      );
      logger.log(
        string.concat(hubLabels[i], ' HubConfigurator'),
        report.hubBatchReport.report.hubConfiguratorAddress
      );
    }
    logger.writeGroup('Hubs', hubEntries);

    // Deploy Spoke Instance Batches
    uint256 spokeCount = spokeLabels.length;
    Logger.AddressEntry[] memory spokeEntries = new Logger.AddressEntry[](spokeCount);
    for (uint256 i; i < spokeCount; i++) {
      report.spokeInstanceBatchReport.label = spokeLabels[i];
      report.spokeInstanceBatchReport.report = _deploySpokeInstanceBatch(
        deployer,
        admin,
        report.accessBatchReport.accessManagerAddress,
        spokeLabels[i]
      );
      spokeEntries[i] = Logger.AddressEntry({
        label: spokeLabels[i],
        value: report.spokeInstanceBatchReport.report.spokeProxyAddress
      });
      logger.log(
        string.concat(spokeLabels[i], ' SpokeInstance Proxy'),
        report.spokeInstanceBatchReport.report.spokeProxyAddress
      );
      logger.log(
        string.concat(spokeLabels[i], ' SpokeInstance Implementation'),
        report.spokeInstanceBatchReport.report.spokeImplementationAddress
      );
      logger.log(
        string.concat(spokeLabels[i], ' AaveOracle'),
        report.spokeInstanceBatchReport.report.aaveOracleAddress
      );
      logger.log(
        string.concat(spokeLabels[i], ' SpokeConfigurator'),
        report.spokeInstanceBatchReport.report.spokeConfiguratorAddress
      );
    }
    logger.writeGroup('SpokeInstances', spokeEntries);

    // Deploy Gateways Batch
    report.gatewaysBatchReport = _deployGatewaysBatch(admin, nativeWrapper);
    logger.log('NativeTokenGateway', report.gatewaysBatchReport.nativeGatewayAddress);
    logger.log('SignatureGateway', report.gatewaysBatchReport.signatureGatewayAddress);

    return report;
  }

  function deployHub(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string memory label
  ) internal returns (HubDeploymentReport memory) {
    HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch(admin, accessManagerAddress);
    logger.write('Hub', hubReport.report.hubAddress);
    logger.write('InterestRateStrategy', hubReport.report.irStrategyAddress);
    logger.write('TreasurySpoke', hubReport.report.treasurySpokeAddress);
    logger.write('HubConfigurator', hubReport.report.hubConfiguratorAddress);
    return hubReport;
  }

  function deploySpoke(
    Logger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label
  ) internal returns (SpokeDeploymentReport memory) {
    SpokeDeploymentReport memory spokeReport;
    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch(deployer, admin, accessManagerAddress, label);
    logger.write('SpokeInstance Proxy', spokeReport.report.spokeProxyAddress);
    logger.write('SpokeInstance Implementation', spokeReport.report.spokeImplementationAddress);
    logger.write('AaveOracle', spokeReport.report.aaveOracleAddress);
    logger.write('SpokeConfigurator', spokeReport.report.spokeConfiguratorAddress);
    return spokeReport;
  }

  function _deployAccessBatch(
    address admin
  ) internal returns (BatchReports.AccessBatchReport memory) {
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin);
    return accessBatch.getReport();
  }

  function _deployHubBatch(
    address admin,
    address accessManagerAddress
  ) internal returns (BatchReports.HubBatchReport memory) {
    AaveV4HubBatch hubBatch = new AaveV4HubBatch(admin, accessManagerAddress);
    return hubBatch.getReport();
  }

  function _deploySpokeInstanceBatch(
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch(
      vm,
      deployer,
      admin,
      accessManagerAddress,
      ORACLE_DECIMALS,
      string.concat(label, ORACLE_SUFFIX)
    );
    return spokeInstanceBatch.getReport();
  }

  function _deployGatewaysBatch(
    address admin,
    address nativeWrapper
  ) internal returns (BatchReports.GatewaysBatchReport memory) {
    AaveV4GatewaysBatch gatewaysBatch = new AaveV4GatewaysBatch(admin, nativeWrapper);
    return gatewaysBatch.getReport();
  }
}
