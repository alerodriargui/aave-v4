// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {Logger} from 'src/deployments/utils/Logger.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4DeployCore} from 'src/deployments/orchestration/AaveV4DeployCore.sol';

import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';

import {
  AaveV4AccessManagerRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {
  AaveV4HubRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {
  AaveV4SpokeRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';

library AaveV4DeployOrchestration {
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
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    // Deploy Access Batch
    address accessManagerAdmin = setRoles ? deployer : admin;
    report.accessBatchReport = _deployAccessBatch(logger, accessManagerAdmin);

    // Deploy Configurator Batch
    report.configuratorBatchReport = _deployConfiguratorBatch(logger, admin);

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs(
      logger,
      admin,
      report.accessBatchReport.accessManagerAddress,
      hubLabels,
      setRoles
    );

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes(
      logger,
      admin,
      report.accessBatchReport.accessManagerAddress,
      spokeLabels,
      setRoles
    );

    // Deploy Gateways Batch
    report.gatewaysBatchReport = _deployGatewayBatch(logger, admin, nativeWrapper);

    // Set Roles if needed
    if (setRoles) {
      logger.log('...Granting Hub Admin role...');
      AaveV4HubRolesProcedure.grantHubAdminRole(
        report.accessBatchReport.accessManagerAddress,
        admin
      );

      logger.log('...Granting Spoke Admin role...');
      AaveV4SpokeRolesProcedure.grantSpokeAdminRole(
        report.accessBatchReport.accessManagerAddress,
        admin
      );

      logger.log('...Granting Configurator roles...');
      AaveV4HubRolesProcedure.grantHubConfiguratorRole({
        accessManagerAddress: report.accessBatchReport.accessManagerAddress,
        hubConfiguratorAddress: report.configuratorBatchReport.hubConfiguratorAddress
      });
      AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole({
        accessManagerAddress: report.accessBatchReport.accessManagerAddress,
        spokeConfiguratorAddress: report.configuratorBatchReport.spokeConfiguratorAddress
      });

      logger.log('...Granting AccessManager Root Admin role...');
      AaveV4AccessManagerRolesProcedure.grantRootAdminRole(
        report.accessBatchReport.accessManagerAddress,
        admin,
        deployer
      );
    }

    return
      _generateFullReport(
        report.accessBatchReport,
        report.configuratorBatchReport,
        report.hubBatchReports,
        report.spokeInstanceBatchReports,
        report.gatewaysBatchReport
      );
  }

  function _deployAccessBatch(
    Logger logger,
    address admin
  ) internal returns (BatchReports.AccessBatchReport memory report) {
    logger.log('...Deploying AccessBatch...');

    report = AaveV4DeployCore.deployAccessBatch(admin);

    logger.log('AccessManager', report.accessManagerAddress);
    logger.log('');
    return report;
  }

  function _deployConfiguratorBatch(
    Logger logger,
    address admin
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.log('...Deploying ConfiguratorBatch...');

    report = AaveV4DeployCore.deployConfiguratorBatch(admin);

    logger.log('HubConfigurator', report.hubConfiguratorAddress);
    logger.log('SpokeConfigurator', report.spokeConfiguratorAddress);
    logger.log('');
    return report;
  }

  function _deployHubs(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string[] memory hubLabels,
    bool setRoles
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      hubBatchReports[i] = _deployHub(logger, admin, accessManagerAddress, hubLabels[i], setRoles);
    }
    logger.log('');
    return hubBatchReports;
  }

  function _deployHub(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch(logger, admin, accessManagerAddress);

    logger.log(label);
    logger.log('  Hub', hubReport.report.hubAddress);
    logger.log('  InterestRateStrategy', hubReport.report.irStrategyAddress);
    logger.log('  TreasurySpoke', hubReport.report.treasurySpokeAddress);

    if (setRoles) {
      logger.log('...Setting Hub roles...');

      AaveV4HubRolesProcedure.setHubAdminRole(accessManagerAddress, hubReport.report.hubAddress);
      AaveV4HubRolesProcedure.setHubConfiguratorRole(
        accessManagerAddress,
        hubReport.report.hubAddress
      );
    }

    return hubReport;
  }

  function _deploySpokes(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string[] memory spokeLabels,
    bool setRoles
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = spokeLabels.length;
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      spokeBatchReports[i] = _deploySpoke(
        logger,
        admin,
        accessManagerAddress,
        spokeLabels[i],
        setRoles
      );
    }
    logger.log('');
    return spokeBatchReports;
  }

  function _deploySpoke(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch(logger, admin, accessManagerAddress, label);

    logger.log(label);
    logger.log('  SpokeInstance Proxy', spokeReport.report.spokeProxyAddress);
    logger.log('  SpokeInstance Implementation', spokeReport.report.spokeImplementationAddress);
    logger.log('  AaveOracle', spokeReport.report.aaveOracleAddress);

    if (setRoles) {
      logger.log('...Setting Spoke roles...');

      AaveV4SpokeRolesProcedure.setSpokeConfiguratorRole(
        accessManagerAddress,
        spokeReport.report.spokeProxyAddress
      );
      AaveV4SpokeRolesProcedure.setSpokeAdminRole(
        accessManagerAddress,
        spokeReport.report.spokeProxyAddress
      );
    }

    return spokeReport;
  }

  function _deploySpokeInstanceBatch(
    Logger logger,
    address admin,
    address accessManagerAddress,
    string memory label
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.log('...Deploying AaveV4SpokeInstanceBatch...');
    report = AaveV4DeployCore.deploySpokeInstanceBatch(
      admin,
      accessManagerAddress,
      ORACLE_DECIMALS,
      ORACLE_SUFFIX,
      label
    );
    return report;
  }

  function _deployHubBatch(
    Logger logger,
    address admin,
    address accessManagerAddress
  ) internal returns (BatchReports.HubBatchReport memory report) {
    logger.log('...Deploying HubBatch...');
    report = AaveV4DeployCore.deployHubBatch(admin, accessManagerAddress);
    return report;
  }

  function _deployGatewayBatch(
    Logger logger,
    address admin,
    address nativeWrapper
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.log('...Deploying GatewayBatch...');
    report = AaveV4DeployCore.deployGatewaysBatch(admin, nativeWrapper);
    logger.log('NativeTokenGateway', report.nativeGatewayAddress);
    logger.log('SignatureGateway', report.signatureGatewayAddress);
    return report;
  }

  function _generateFullReport(
    BatchReports.AccessBatchReport memory accessBatchReport,
    BatchReports.ConfiguratorBatchReport memory configuratorBatchReport,
    OrchestrationReports.HubDeploymentReport[] memory hubBatchReports,
    OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports,
    BatchReports.GatewaysBatchReport memory gatewaysBatchReport
  ) internal pure returns (OrchestrationReports.FullDeploymentReport memory report) {
    report.accessBatchReport = accessBatchReport;
    report.configuratorBatchReport = configuratorBatchReport;
    report.hubBatchReports = hubBatchReports;
    report.spokeInstanceBatchReports = spokeBatchReports;
    report.gatewaysBatchReport = gatewaysBatchReport;
    return report;
  }
}
