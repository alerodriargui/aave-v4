// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// import 'forge-std/Vm.sol';

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
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';

library AaveV4DeployOrchestration {
  uint8 private constant ORACLE_DECIMALS = 8;
  string private constant ORACLE_SUFFIX = ' (USD)';

  function deployAaveV4(
    Logger logger,
    address deployer,
    InputUtils.FullDeployInputs memory deployInputs
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    // Deploy Access Batch
    // initially with provided access manager admin (fallback to deployer if zero)
    address initialAdmin = deployer;
    report.accessBatchReport = _deployAccessBatch({
      logger: logger,
      accessManagerAdmin: initialAdmin
    });

    // if any admin is zero address, default to deployer as admin
    InputUtils.FullDeployInputs memory inputs = deployInputs;
    inputs.accessManagerAdmin = deployInputs.accessManagerAdmin != address(0)
      ? deployInputs.accessManagerAdmin
      : deployer;
    inputs.hubConfiguratorOwner = deployInputs.hubConfiguratorOwner != address(0)
      ? deployInputs.hubConfiguratorOwner
      : deployer;
    inputs.treasurySpokeOwner = deployInputs.treasurySpokeOwner != address(0)
      ? deployInputs.treasurySpokeOwner
      : deployer;
    inputs.spokeProxyAdminOwner = deployInputs.spokeProxyAdminOwner != address(0)
      ? deployInputs.spokeProxyAdminOwner
      : deployer;
    inputs.spokeConfiguratorOwner = deployInputs.spokeConfiguratorOwner != address(0)
      ? deployInputs.spokeConfiguratorOwner
      : deployer;
    inputs.gatewayOwner = deployInputs.gatewayOwner != address(0)
      ? deployInputs.gatewayOwner
      : deployer;

    // Deploy Configurator Batch
    report.configuratorBatchReport = _deployConfiguratorBatch({
      logger: logger,
      hubConfiguratorOwner: inputs.hubConfiguratorOwner,
      spokeConfiguratorOwner: inputs.spokeConfiguratorOwner
    });

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs({
      logger: logger,
      treasurySpokeOwner: inputs.treasurySpokeOwner,
      accessManagerAddress: report.accessBatchReport.accessManagerAddress,
      hubLabels: inputs.hubLabels
    });

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes({
      logger: logger,
      spokeProxyAdminOwner: inputs.spokeProxyAdminOwner,
      accessManagerAddress: report.accessBatchReport.accessManagerAddress,
      spokeLabels: inputs.spokeLabels
    });

    // Deploy Gateways Batch
    report.gatewaysBatchReport = _deployGatewayBatch({
      logger: logger,
      gatewayOwner: inputs.gatewayOwner,
      nativeWrapper: inputs.nativeWrapperAddress
    });

    // Set Roles if needed
    if (inputs.grantRoles) {
      if (inputs.hubLabels.length > 0) {
        _grantHubRoles({logger: logger, report: report, hubAdmin: inputs.hubAdmin});
      }
      if (inputs.spokeLabels.length > 0) {
        _grantSpokeRoles({logger: logger, report: report, spokeAdmin: inputs.spokeAdmin});
      }

      if (inputs.accessManagerAdmin != initialAdmin) {
        logger.log('...Granting AccessManager Root Admin role...');
        AaveV4AccessManagerRolesProcedure.grantRootAdminRole({
          accessManagerAddress: report.accessBatchReport.accessManagerAddress,
          newAdminAddress: inputs.accessManagerAdmin,
          currentAdminAddress: initialAdmin
        });
      }
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

  function _grantHubRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address hubAdmin
  ) internal {
    logger.log('...Granting Hub Admin role...');
    AaveV4HubRolesProcedure.grantHubAdminRole({
      accessManagerAddress: report.accessBatchReport.accessManagerAddress,
      admin: hubAdmin
    });

    logger.log('...Granting Hub Configurator roles...');
    AaveV4HubRolesProcedure.grantHubConfiguratorRole({
      accessManagerAddress: report.accessBatchReport.accessManagerAddress,
      admin: report.configuratorBatchReport.hubConfiguratorAddress
    });
  }

  function _grantSpokeRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address spokeAdmin
  ) internal {
    logger.log('...Granting Spoke Admin role...');
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole({
      accessManagerAddress: report.accessBatchReport.accessManagerAddress,
      admin: spokeAdmin
    });

    logger.log('...Granting Spoke Configurator roles...');
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole({
      accessManagerAddress: report.accessBatchReport.accessManagerAddress,
      admin: report.configuratorBatchReport.spokeConfiguratorAddress
    });
  }

  function _deployAccessBatch(
    Logger logger,
    address accessManagerAdmin
  ) internal returns (BatchReports.AccessBatchReport memory report) {
    logger.log('...Deploying AccessBatch...');

    report = AaveV4DeployCore.deployAccessBatch({admin: accessManagerAdmin});

    logger.log('AccessManager', report.accessManagerAddress);
    logger.log('');
    return report;
  }

  function _deployConfiguratorBatch(
    Logger logger,
    address hubConfiguratorOwner,
    address spokeConfiguratorOwner
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.log('...Deploying ConfiguratorBatch...');

    report = AaveV4DeployCore.deployConfiguratorBatch({
      hubConfiguratorOwner: hubConfiguratorOwner,
      spokeConfiguratorOwner: spokeConfiguratorOwner
    });

    logger.log('HubConfigurator', report.hubConfiguratorAddress);
    logger.log('SpokeConfigurator', report.spokeConfiguratorAddress);
    logger.log('');
    return report;
  }

  function _deployHubs(
    Logger logger,
    address treasurySpokeOwner,
    address accessManagerAddress,
    string[] memory hubLabels
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      hubBatchReports[i] = _deployHub(
        logger,
        treasurySpokeOwner,
        accessManagerAddress,
        hubLabels[i]
      );
    }
    logger.log('');
    return hubBatchReports;
  }

  function _deployHub(
    Logger logger,
    address treasurySpokeOwner,
    address accessManagerAddress,
    string memory label
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch({
      logger: logger,
      treasurySpokeOwner: treasurySpokeOwner,
      accessManagerAddress: accessManagerAddress
    });

    logger.log(label);
    logger.log('  Hub', hubReport.report.hubAddress);
    logger.log('  InterestRateStrategy', hubReport.report.irStrategyAddress);
    logger.log('  TreasurySpoke', hubReport.report.treasurySpokeAddress);

    logger.log('...Setting Hub roles...');
    AaveV4HubRolesProcedure.setHubRoles(accessManagerAddress, hubReport.report.hubAddress);

    return hubReport;
  }

  function _deploySpokes(
    Logger logger,
    address spokeProxyAdminOwner,
    address accessManagerAddress,
    string[] memory spokeLabels
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = spokeLabels.length;
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      spokeBatchReports[i] = _deploySpoke({
        logger: logger,
        spokeProxyAdminOwner: spokeProxyAdminOwner,
        accessManagerAddress: accessManagerAddress,
        label: spokeLabels[i]
      });
    }
    logger.log('');
    return spokeBatchReports;
  }

  function _deploySpoke(
    Logger logger,
    address spokeProxyAdminOwner,
    address accessManagerAddress,
    string memory label
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch({
      logger: logger,
      spokeProxyAdminOwner: spokeProxyAdminOwner,
      accessManagerAddress: accessManagerAddress,
      label: label
    });

    logger.log(label);
    logger.log('  SpokeInstance Proxy', spokeReport.report.spokeProxyAddress);
    logger.log('  SpokeInstance Implementation', spokeReport.report.spokeImplementationAddress);
    logger.log('  AaveOracle', spokeReport.report.aaveOracleAddress);

    logger.log('...Setting Spoke roles...');
    AaveV4SpokeRolesProcedure.setSpokeRoles({
      accessManagerAddress: accessManagerAddress,
      spokeAddress: spokeReport.report.spokeProxyAddress
    });

    return spokeReport;
  }

  function _deploySpokeInstanceBatch(
    Logger logger,
    address spokeProxyAdminOwner,
    address accessManagerAddress,
    string memory label
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.log('...Deploying AaveV4SpokeInstanceBatch...');
    report = AaveV4DeployCore.deploySpokeInstanceBatch(
      spokeProxyAdminOwner,
      accessManagerAddress,
      ORACLE_DECIMALS,
      ORACLE_SUFFIX,
      label
    );
    return report;
  }

  function _deployHubBatch(
    Logger logger,
    address treasurySpokeOwner,
    address accessManagerAddress
  ) internal returns (BatchReports.HubBatchReport memory report) {
    logger.log('...Deploying HubBatch...');
    report = AaveV4DeployCore.deployHubBatch(treasurySpokeOwner, accessManagerAddress);
    return report;
  }

  function _deployGatewayBatch(
    Logger logger,
    address gatewayOwner,
    address nativeWrapper
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.log('...Deploying GatewayBatch...');
    report = AaveV4DeployCore.deployGatewaysBatch({
      owner: gatewayOwner,
      nativeWrapper: nativeWrapper
    });
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
