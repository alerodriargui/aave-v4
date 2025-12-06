// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {IProgressLogger} from 'src/deployments/utils/interfaces/IProgressLogger.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {AaveV4DeployCore} from 'src/deployments/orchestration/AaveV4DeployCore.sol';

import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';

import {
  AaveV4AdminRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4AdminRolesProcedure.sol';
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
    IProgressLogger logger,
    address deployer,
    address admin,
    address nativeWrapper,
    string[] memory hubLabels,
    string[] memory spokeLabels,
    bool setRoles,
    bool broadcast
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    // Deploy Access Batch
    address accessManagerAdmin = setRoles ? deployer : admin;
    report.accessBatchReport = _deployAccessBatch(logger, deployer, accessManagerAdmin, broadcast);

    // Deploy Configurator Batch
    report.configuratorBatchReport = _deployConfiguratorBatch(logger, deployer, admin, broadcast);

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs(
      logger,
      deployer,
      admin,
      report.accessBatchReport.accessManagerAddress,
      hubLabels,
      setRoles,
      broadcast
    );

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes(
      logger,
      deployer,
      admin,
      report.accessBatchReport.accessManagerAddress,
      spokeLabels,
      setRoles,
      broadcast
    );

    // Deploy Gateways Batch
    report.gatewaysBatchReport = _deployGatewayBatch(
      logger,
      deployer,
      admin,
      nativeWrapper,
      broadcast
    );

    // Set Roles if needed
    if (setRoles) {
      logger.log('...Setting Configurator roles...');

      _startBroadcastIf(broadcast, deployer);
      AaveV4AdminRolesProcedure.setConfiguratorAdminRoles(
        report.accessBatchReport.accessManagerAddress,
        report.configuratorBatchReport.spokeConfiguratorAddress,
        report.configuratorBatchReport.hubConfiguratorAddress
      );
      _stopBroadcastIf(broadcast);

      logger.log('...Setting AccessManager Root Admin role...');

      _startBroadcastIf(broadcast, deployer);
      AaveV4AdminRolesProcedure.setAccessManagerRootAdminRole(
        report.accessBatchReport.accessManagerAddress,
        admin,
        deployer
      );
      _stopBroadcastIf(broadcast);
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
    IProgressLogger logger,
    address deployer,
    address admin,
    bool broadcast
  ) internal returns (BatchReports.AccessBatchReport memory report) {
    logger.log('...Deploying AccessBatch...');

    _startBroadcastIf(broadcast, deployer);
    report = AaveV4DeployCore.deployAccessBatch(admin);
    _stopBroadcastIf(broadcast);

    logger.log('AccessManager', report.accessManagerAddress);
    logger.log('');
    return report;
  }

  function _deployConfiguratorBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    bool broadcast
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.log('...Deploying ConfiguratorBatch...');

    _startBroadcastIf(broadcast, deployer);
    report = AaveV4DeployCore.deployConfiguratorBatch(admin);
    _stopBroadcastIf(broadcast);

    logger.log('HubConfigurator', report.hubConfiguratorAddress);
    logger.log('SpokeConfigurator', report.spokeConfiguratorAddress);
    logger.log('');
    return report;
  }

  function _deployHubs(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string[] memory hubLabels,
    bool setRoles,
    bool broadcast
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      hubBatchReports[i] = _deployHub(
        logger,
        deployer,
        admin,
        accessManagerAddress,
        hubLabels[i],
        setRoles,
        broadcast
      );
    }
    logger.log('');
    return hubBatchReports;
  }

  function _deployHub(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles,
    bool broadcast
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch(logger, deployer, admin, accessManagerAddress, broadcast);

    logger.log(label);
    logger.log('  Hub', hubReport.report.hubAddress);
    logger.log('  InterestRateStrategy', hubReport.report.irStrategyAddress);
    logger.log('  TreasurySpoke', hubReport.report.treasurySpokeAddress);

    if (setRoles) {
      logger.log('...Setting Hub roles...');

      _startBroadcastIf(broadcast, deployer);
      AaveV4HubRolesProcedure.setHubRoles(accessManagerAddress, hubReport.report.hubAddress);
      _stopBroadcastIf(broadcast);
    }

    return hubReport;
  }

  function _deploySpokes(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string[] memory spokeLabels,
    bool setRoles,
    bool broadcast
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = spokeLabels.length;
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      spokeBatchReports[i] = _deploySpoke(
        logger,
        deployer,
        admin,
        accessManagerAddress,
        spokeLabels[i],
        setRoles,
        broadcast
      );
    }
    logger.log('');
    return spokeBatchReports;
  }

  function _deploySpoke(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles,
    bool broadcast
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch(
      logger,
      deployer,
      admin,
      accessManagerAddress,
      label,
      broadcast
    );

    logger.log(label);
    logger.log('  SpokeInstance Proxy', spokeReport.report.spokeProxyAddress);
    logger.log('  SpokeInstance Implementation', spokeReport.report.spokeImplementationAddress);
    logger.log('  AaveOracle', spokeReport.report.aaveOracleAddress);

    if (setRoles) {
      logger.log('...Setting Spoke roles...');

      _startBroadcastIf(broadcast, deployer);
      AaveV4SpokeRolesProcedure.setSpokeRoles(
        accessManagerAddress,
        spokeReport.report.spokeProxyAddress
      );
      AaveV4SpokeRolesProcedure.setSpokeUserPositionAdapterRole(
        accessManagerAddress,
        spokeReport.report.spokeProxyAddress
      );
      _stopBroadcastIf(broadcast);
    }

    return spokeReport;
  }

  function _deployHubBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    bool broadcast
  ) internal returns (BatchReports.HubBatchReport memory report) {
    logger.log('...Deploying HubBatch...');

    _startBroadcastIf(broadcast, deployer);
    report = AaveV4DeployCore.deployHubBatch(admin, accessManagerAddress);
    _stopBroadcastIf(broadcast);

    return report;
  }

  function _deploySpokeInstanceBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool broadcast
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.log('...Deploying AaveV4SpokeInstanceBatch...');

    _startBroadcastIf(broadcast, deployer);
    report = AaveV4DeployCore.deploySpokeInstanceBatch(
      admin,
      accessManagerAddress,
      ORACLE_DECIMALS,
      ORACLE_SUFFIX,
      label
    );
    _stopBroadcastIf(broadcast);

    return report;
  }

  function _deployGatewayBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    address nativeWrapper,
    bool broadcast
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.log('...Deploying GatewayBatch...');

    _startBroadcastIf(broadcast, deployer);
    report = AaveV4DeployCore.deployGatewaysBatch(admin, nativeWrapper);
    _stopBroadcastIf(broadcast);

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

  function _startBroadcastIf(bool broadcast, address deployer) private {
    if (broadcast) vm.startBroadcast(deployer);
  }

  function _stopBroadcastIf(bool broadcast) private {
    if (broadcast) vm.stopBroadcast();
  }
}
