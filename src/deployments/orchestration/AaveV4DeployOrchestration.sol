// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';

import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

library AaveV4DeployOrchestration {
  uint8 private constant ORACLE_DECIMALS = 8;
  string private constant ORACLE_SUFFIX = ' (USD)';
  uint16 private constant MAX_ALLOWED_USER_RESERVES_LIMIT = type(uint16).max; // TODO : see to make this input in config

  function deployAaveV4(
    Logger logger,
    address deployer,
    InputUtils.FullDeployInputs memory deployInputs
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    bytes32 rootSalt = keccak256(abi.encode(deployInputs.salt));

    // Deploy Access Batch
    // initialize with deployer as access manager admin
    address initialAdmin = deployer;
    report.accessBatchReport = _deployAccessBatch({
      logger: logger,
      accessManagerAdmin: initialAdmin,
      salt: rootSalt
    });

    // Deploy Configurator Batch with AccessManager as authority
    report.configuratorBatchReport = _deployConfiguratorBatch({
      logger: logger,
      hubConfiguratorAuthority: report.accessBatchReport.accessManager,
      spokeConfiguratorAuthority: report.accessBatchReport.accessManager,
      salt: keccak256(abi.encode(rootSalt, 'config'))
    });

    // Setup Configurator Roles
    logger.log('...Setting HubConfigurator roles...');
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRoles(
      report.accessBatchReport.accessManager,
      report.configuratorBatchReport.hubConfigurator
    );
    logger.log('...Setting SpokeConfigurator roles...');
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      report.accessBatchReport.accessManager,
      report.configuratorBatchReport.spokeConfigurator
    );

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs({
      logger: logger,
      treasurySpokeOwner: deployInputs.treasurySpokeOwner,
      authority: report.accessBatchReport.accessManager,
      hubLabels: deployInputs.hubLabels,
      rootSalt: rootSalt
    });

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes({
      logger: logger,
      spokeProxyAdminOwner: deployInputs.spokeProxyAdminOwner,
      authority: report.accessBatchReport.accessManager,
      spokeLabels: deployInputs.spokeLabels,
      rootSalt: rootSalt
    });

    // Deploy Gateways Batch if native wrapper is not zero address
    if (deployInputs.nativeWrapper != address(0)) {
      report.gatewaysBatchReport = _deployGatewayBatch({
        logger: logger,
        gatewayOwner: deployInputs.gatewayOwner,
        nativeWrapper: deployInputs.nativeWrapper,
        salt: keccak256(abi.encode(rootSalt, 'gateways'))
      });
    }

    // Set Roles if needed
    if (deployInputs.grantRoles) {
      if (deployInputs.hubLabels.length > 0) {
        _grantHubRoles({
          logger: logger,
          report: report,
          hubAdmin: deployInputs.hubAdmin,
          hubConfiguratorAdmin: deployInputs.hubConfiguratorAdmin
        });
      }
      if (deployInputs.spokeLabels.length > 0) {
        _grantSpokeRoles({
          logger: logger,
          report: report,
          spokeAdmin: deployInputs.spokeAdmin,
          spokeConfiguratorAdmin: deployInputs.spokeConfiguratorAdmin
        });
      }

      if (deployInputs.accessManagerAdmin != initialAdmin) {
        logger.log('...Granting AccessManager Root Admin role...');
        AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
          accessManager: report.accessBatchReport.accessManager,
          adminToAdd: deployInputs.accessManagerAdmin,
          adminToRemove: initialAdmin
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
    address hubAdmin,
    address hubConfiguratorAdmin
  ) internal {
    logger.log('...Granting Hub Admin role...');
    AaveV4HubRolesProcedure.grantHubAdminRole({
      accessManager: report.accessBatchReport.accessManager,
      admin: hubAdmin
    });

    logger.log('...Granting Hub Configurator roles...');
    AaveV4HubRolesProcedure.grantHubConfiguratorRole({
      accessManager: report.accessBatchReport.accessManager,
      admin: report.configuratorBatchReport.hubConfigurator
    });

    logger.log('...Granting HubConfigurator Admin roles...');
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: report.accessBatchReport.accessManager,
      admin: hubConfiguratorAdmin
    });
  }

  function _grantSpokeRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address spokeAdmin,
    address spokeConfiguratorAdmin
  ) internal {
    logger.log('...Granting Spoke Admin role...');
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole({
      accessManager: report.accessBatchReport.accessManager,
      admin: spokeAdmin
    });

    logger.log('...Granting Spoke Configurator roles...');
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole({
      accessManager: report.accessBatchReport.accessManager,
      admin: report.configuratorBatchReport.spokeConfigurator
    });

    logger.log('...Granting SpokeConfigurator Admin roles...');
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: report.accessBatchReport.accessManager,
      admin: spokeConfiguratorAdmin
    });
  }

  function _deployAccessBatch(
    Logger logger,
    address accessManagerAdmin,
    bytes32 salt
  ) internal returns (BatchReports.AccessBatchReport memory report) {
    logger.log('...Deploying AccessBatch...');

    report = AaveV4DeployBase.deployAccessBatch({admin: accessManagerAdmin, salt: salt});

    logger.log('AccessManager', report.accessManager);
    logger.log('');
    return report;
  }

  function _deployConfiguratorBatch(
    Logger logger,
    address hubConfiguratorAuthority,
    address spokeConfiguratorAuthority,
    bytes32 salt
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.log('...Deploying ConfiguratorBatch...');

    report = AaveV4DeployBase.deployConfiguratorBatch({
      hubConfiguratorAuthority: hubConfiguratorAuthority,
      spokeConfiguratorAuthority: spokeConfiguratorAuthority,
      salt: salt
    });

    logger.log('HubConfigurator', report.hubConfigurator);
    logger.log('SpokeConfigurator', report.spokeConfigurator);
    logger.log('');
    return report;
  }

  function _deployHubs(
    Logger logger,
    address treasurySpokeOwner,
    address authority,
    string[] memory hubLabels,
    bytes32 rootSalt
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      hubBatchReports[i] = _deployHub({
        logger: logger,
        treasurySpokeOwner: treasurySpokeOwner,
        authority: authority,
        label: hubLabels[i],
        salt: keccak256(abi.encode(rootSalt, 'hub', hubLabels[i]))
      });
    }
    logger.log('');
    return hubBatchReports;
  }

  function _deployHub(
    Logger logger,
    address treasurySpokeOwner,
    address authority,
    string memory label,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch({
      logger: logger,
      treasurySpokeOwner: treasurySpokeOwner,
      authority: authority,
      salt: salt
    });

    logger.log(label);
    logger.log('  Hub', hubReport.report.hub);
    logger.log('  InterestRateStrategy', hubReport.report.irStrategy);
    logger.log('  TreasurySpoke', hubReport.report.treasurySpoke);

    logger.log('...Setting Hub roles...');
    AaveV4HubRolesProcedure.setupHubRoles(authority, hubReport.report.hub);

    return hubReport;
  }

  function _deploySpokes(
    Logger logger,
    address spokeProxyAdminOwner,
    address authority,
    string[] memory spokeLabels,
    bytes32 rootSalt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = spokeLabels.length;
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      spokeBatchReports[i] = _deploySpoke({
        logger: logger,
        spokeProxyAdminOwner: spokeProxyAdminOwner,
        authority: authority,
        label: spokeLabels[i],
        salt: keccak256(abi.encode(rootSalt, 'spoke', spokeLabels[i]))
      });
    }
    logger.log('');
    return spokeBatchReports;
  }

  function _deploySpoke(
    Logger logger,
    address spokeProxyAdminOwner,
    address authority,
    string memory label,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch({
      logger: logger,
      spokeProxyAdminOwner: spokeProxyAdminOwner,
      authority: authority,
      label: label,
      salt: salt
    });

    logger.log(label);
    logger.log('  SpokeInstance Proxy', spokeReport.report.spokeProxy);
    logger.log('  SpokeInstance Implementation', spokeReport.report.spokeImplementation);
    logger.log('  AaveOracle', spokeReport.report.aaveOracle);

    logger.log('...Setting Spoke roles...');
    AaveV4SpokeRolesProcedure.setupSpokeRoles({
      accessManager: authority,
      spoke: spokeReport.report.spokeProxy
    });

    return spokeReport;
  }

  function _deploySpokeInstanceBatch(
    Logger logger,
    address spokeProxyAdminOwner,
    address authority,
    string memory label,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.log('...Deploying AaveV4SpokeInstanceBatch...');
    report = AaveV4DeployBase.deploySpokeInstanceBatch({
      spokeProxyAdminOwner: spokeProxyAdminOwner,
      authority: authority,
      oracleDecimals: ORACLE_DECIMALS,
      oracleSuffix: ORACLE_SUFFIX,
      label: label,
      maxUserReservesLimit: MAX_ALLOWED_USER_RESERVES_LIMIT,
      salt: salt
    });
    return report;
  }

  function _deployHubBatch(
    Logger logger,
    address treasurySpokeOwner,
    address authority,
    bytes32 salt
  ) internal returns (BatchReports.HubBatchReport memory report) {
    logger.log('...Deploying HubBatch...');
    report = AaveV4DeployBase.deployHubBatch({
      treasurySpokeOwner: treasurySpokeOwner,
      authority: authority,
      salt: salt
    });
    return report;
  }

  function _deployGatewayBatch(
    Logger logger,
    address gatewayOwner,
    address nativeWrapper,
    bytes32 salt
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.log('...Deploying GatewayBatch...');
    report = AaveV4DeployBase.deployGatewaysBatch({
      owner: gatewayOwner,
      nativeWrapper: nativeWrapper,
      salt: salt
    });
    logger.log('NativeTokenGateway', report.nativeGateway);
    logger.log('SignatureGateway', report.signatureGateway);
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
