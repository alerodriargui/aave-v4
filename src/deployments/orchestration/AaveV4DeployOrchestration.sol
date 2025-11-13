// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {Logger} from 'src/deployments/utils/Logger.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';

import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4GatewaysBatch} from 'src/deployments/batches/AaveV4GatewaysBatch.sol';

import {AaveV4AdminRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AdminRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';

library AaveV4DeployOrchestration {
  bool public constant IS_TEST = true;
  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  uint8 private constant ORACLE_DECIMALS = 8;
  string private constant ORACLE_SUFFIX = ' (USD)';

  function deployAaveV4(
    Logger logger,
    address deployer,
    address admin,
    address nativeWrapper,
    string[] memory hubLabels,
    string[] memory spokeLabels,
    bool setRoles
  ) internal returns (OrchestrationReports.FullDeploymentReport memory) {
    OrchestrationReports.FullDeploymentReport memory report;

    // Deploy Access Batch
    address accessManagerAdmin = setRoles ? deployer : admin;
    report.accessBatchReport = _deployAccessBatch(accessManagerAdmin);
    logger.log('AccessManager', report.accessBatchReport.accessManagerAddress);

    // Deploy Configurator Batch
    report.configuratorBatchReport = _deployConfiguratorBatch(admin);
    logger.log('HubConfigurator', report.configuratorBatchReport.hubConfiguratorAddress);
    logger.log('SpokeConfigurator', report.configuratorBatchReport.spokeConfiguratorAddress);

    // Deploy Hub Batches
    uint256 hubCount = hubLabels.length;
    report.hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      report.hubBatchReports[i].label = hubLabels[i];
      report.hubBatchReports[i].report = _deployHubBatch(
        admin,
        report.accessBatchReport.accessManagerAddress
      );
      hubEntries[i] = Logger.AddressEntry({
        label: hubLabels[i],
        value: report.hubBatchReports[i].report.hubAddress
      });
      logger.log(string.concat(hubLabels[i], ' Hub'), report.hubBatchReports[i].report.hubAddress);
      logger.log(
        string.concat(hubLabels[i], ' InterestRateStrategy'),
        report.hubBatchReports[i].report.irStrategyAddress
      );
      logger.log(
        string.concat(hubLabels[i], ' TreasurySpoke'),
        report.hubBatchReports[i].report.treasurySpokeAddress
      );
    }
    logger.writeGroup('Hubs', hubEntries);

    // Deploy Spoke Instance Batches
    uint256 spokeCount = spokeLabels.length;
    report.spokeInstanceBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    Logger.AddressEntry[] memory spokeEntries = new Logger.AddressEntry[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      report.spokeInstanceBatchReports[i].label = spokeLabels[i];
      report.spokeInstanceBatchReports[i].report = _deploySpokeInstanceBatch(
        deployer,
        admin,
        report.accessBatchReport.accessManagerAddress,
        spokeLabels[i]
      );
      spokeEntries[i] = Logger.AddressEntry({
        label: spokeLabels[i],
        value: report.spokeInstanceBatchReports[i].report.spokeProxyAddress
      });
      logger.log(
        string.concat(spokeLabels[i], ' SpokeInstance Proxy'),
        report.spokeInstanceBatchReports[i].report.spokeProxyAddress
      );
      logger.log(
        string.concat(spokeLabels[i], ' SpokeInstance Implementation'),
        report.spokeInstanceBatchReports[i].report.spokeImplementationAddress
      );
      logger.log(
        string.concat(spokeLabels[i], ' AaveOracle'),
        report.spokeInstanceBatchReports[i].report.aaveOracleAddress
      );
    }
    logger.writeGroup('SpokeInstances', spokeEntries);

    // Deploy Gateways Batch
    report.gatewaysBatchReport = _deployGatewaysBatch(admin, nativeWrapper);
    logger.log('NativeTokenGateway', report.gatewaysBatchReport.nativeGatewayAddress);
    logger.log('SignatureGateway', report.gatewaysBatchReport.signatureGatewayAddress);

    // Set Roles if needed
    if (setRoles) {
      AaveV4AdminRolesProcedure.setConfiguratorAdminRoles(
        report.accessBatchReport.accessManagerAddress,
        report.configuratorBatchReport.spokeConfiguratorAddress,
        report.configuratorBatchReport.hubConfiguratorAddress
      );
      for (uint256 i; i < hubCount; ++i) {
        AaveV4HubRolesProcedure.setHubRoles(
          report.accessBatchReport.accessManagerAddress,
          report.hubBatchReports[i].report.hubAddress
        );
      }
      for (uint256 i; i < spokeCount; ++i) {
        AaveV4SpokeRolesProcedure.setSpokeRoles(
          report.accessBatchReport.accessManagerAddress,
          report.spokeInstanceBatchReports[i].report.spokeProxyAddress
        );
      }
      AaveV4AdminRolesProcedure.setNewAdminRole(
        report.accessBatchReport.accessManagerAddress,
        admin,
        deployer
      );
    }

    return report;
  }

  function deployHub(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch(admin, accessManagerAddress);
    logger.write('Hub', hubReport.report.hubAddress);
    logger.write('InterestRateStrategy', hubReport.report.irStrategyAddress);
    logger.write('TreasurySpoke', hubReport.report.treasurySpokeAddress);

    if (setRoles) {
      AaveV4HubRolesProcedure.setHubRoles(accessManagerAddress, hubReport.report.hubAddress);
    }

    return hubReport;
  }

  function deploySpoke(
    Logger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;
    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch(deployer, admin, accessManagerAddress, label);
    logger.write('SpokeInstance Proxy', spokeReport.report.spokeProxyAddress);
    logger.write('SpokeInstance Implementation', spokeReport.report.spokeImplementationAddress);
    logger.write('AaveOracle', spokeReport.report.aaveOracleAddress);

    if (setRoles) {
      AaveV4SpokeRolesProcedure.setSpokeRoles(
        accessManagerAddress,
        spokeReport.report.spokeProxyAddress
      );
    }

    return spokeReport;
  }

  function _deployAccessBatch(
    address admin
  ) internal returns (BatchReports.AccessBatchReport memory) {
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin);
    return accessBatch.getReport();
  }

  function _deployConfiguratorBatch(
    address admin
  ) internal returns (BatchReports.ConfiguratorBatchReport memory) {
    AaveV4ConfiguratorBatch configuratorBatch = new AaveV4ConfiguratorBatch(admin);
    return configuratorBatch.getReport();
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
