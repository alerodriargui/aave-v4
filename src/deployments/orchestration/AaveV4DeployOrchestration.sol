// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';
import {AaveV4AuthorityBatch} from 'src/deployments/batches/AaveV4AuthorityBatch.sol';
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
  bytes32 public constant SALT = keccak256('AAVE_V4');

  function deployAaveV4(
    Logger logger,
    address deployer,
    InputUtils.FullDeployInputs memory deployInputs,
    bytes memory hubBytecode,
    bytes memory spokeBytecode
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    bytes32 salt = _deriveSalt(deployInputs.salt);

    // Deploy Access Batch
    // initialize with deployer as access manager admin
    address initialAdmin = deployer;
    report.authorityBatchReport = _deployAuthorityBatch({
      logger: logger,
      accessManagerAdmin: initialAdmin,
      salt: salt
    });

    // Deploy Configurator Batch with AccessManager as authority
    report.configuratorBatchReport = _deployConfiguratorBatch({
      logger: logger,
      hubConfiguratorAuthority: report.authorityBatchReport.accessManager,
      spokeConfiguratorAuthority: report.authorityBatchReport.accessManager,
      salt: salt
    });

    // Setup Configurator Roles
    logger.log('...Setting HubConfigurator roles...');
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles(
      report.authorityBatchReport.accessManager,
      report.configuratorBatchReport.hubConfigurator
    );
    logger.log('...Setting SpokeConfigurator roles...');
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      report.authorityBatchReport.accessManager,
      report.configuratorBatchReport.spokeConfigurator
    );

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs({
      logger: logger,
      treasurySpokeOwner: deployInputs.treasurySpokeOwner,
      authority: report.authorityBatchReport.accessManager,
      hubLabels: deployInputs.hubLabels,
      hubBytecode: hubBytecode,
      salt: salt
    });

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes(
      logger,
      report.authorityBatchReport.accessManager,
      deployInputs,
      spokeBytecode,
      salt
    );

    // Deploy Gateways Batch if either gateway flag is enabled
    if (deployInputs.deployNativeTokenGateway || deployInputs.deploySignatureGateway) {
      report.gatewaysBatchReport = _deployGatewayBatch({
        logger: logger,
        gatewayOwner: deployInputs.gatewayOwner,
        nativeWrapper: deployInputs.nativeWrapper,
        deployNativeTokenGateway: deployInputs.deployNativeTokenGateway,
        deploySignatureGateway: deployInputs.deploySignatureGateway,
        salt: salt
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
          accessManager: report.authorityBatchReport.accessManager,
          adminToAdd: deployInputs.accessManagerAdmin,
          adminToRemove: initialAdmin
        });
      }
    }

    return report;
  }

  function _grantHubRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address hubAdmin,
    address hubConfiguratorAdmin
  ) internal {
    logger.log('...Granting Hub Admin role...');
    AaveV4HubRolesProcedure.grantHubAdminRole({
      accessManager: report.authorityBatchReport.accessManager,
      admin: hubAdmin
    });

    logger.log('...Granting Hub Configurator roles...');
    AaveV4HubRolesProcedure.grantHubConfiguratorRole({
      accessManager: report.authorityBatchReport.accessManager,
      admin: report.configuratorBatchReport.hubConfigurator
    });

    logger.log('...Granting HubConfigurator Admin roles...');
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: report.authorityBatchReport.accessManager,
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
      accessManager: report.authorityBatchReport.accessManager,
      admin: spokeAdmin
    });

    logger.log('...Granting Spoke Configurator roles...');
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole({
      accessManager: report.authorityBatchReport.accessManager,
      admin: report.configuratorBatchReport.spokeConfigurator
    });

    logger.log('...Granting SpokeConfigurator Admin roles...');
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: report.authorityBatchReport.accessManager,
      admin: spokeConfiguratorAdmin
    });
  }

  function _deployAuthorityBatch(
    Logger logger,
    address accessManagerAdmin,
    bytes32 salt
  ) internal returns (BatchReports.AuthorityBatchReport memory report) {
    logger.log('...Deploying AuthorityBatch...');

    report = AaveV4DeployBase.deployAuthorityBatch({admin: accessManagerAdmin, salt: salt});

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
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      hubBatchReports[i] = _deployHub({
        logger: logger,
        treasurySpokeOwner: treasurySpokeOwner,
        authority: authority,
        label: hubLabels[i],
        hubBytecode: hubBytecode,
        salt: keccak256(abi.encode(salt, 'hub', hubLabels[i]))
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
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch({
      logger: logger,
      treasurySpokeOwner: treasurySpokeOwner,
      authority: authority,
      hubBytecode: hubBytecode,
      salt: salt
    });

    _logHubReport(logger, hubReport.report, label);
    _setupHubRoles(logger, hubReport.report, authority);

    return hubReport;
  }

  function _deploySpokes(
    Logger logger,
    address authority,
    InputUtils.FullDeployInputs memory inputs,
    bytes memory spokeBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = inputs.spokeLabels.length;
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      spokeBatchReports[i] = _deploySpoke({
        logger: logger,
        spokeProxyAdminOwner: inputs.spokeProxyAdminOwner,
        authority: authority,
        label: inputs.spokeLabels[i],
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: inputs.spokeMaxReservesLimits[i],
        oracleDecimals: inputs.spokeOracleDecimals[i],
        oracleDescription: inputs.spokeOracleDescriptions[i],
        salt: keccak256(abi.encode(salt, 'spoke', inputs.spokeLabels[i]))
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
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    uint8 oracleDecimals,
    string memory oracleDescription,
    bytes32 salt
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch({
      logger: logger,
      spokeProxyAdminOwner: spokeProxyAdminOwner,
      authority: authority,
      spokeBytecode: spokeBytecode,
      oracleDecimals: oracleDecimals,
      oracleDescription: oracleDescription,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });
    _logSpokeReport(logger, spokeReport.report, label);
    _setupSpokeRoles(logger, spokeReport.report, authority);

    return spokeReport;
  }

  function _deploySpokeInstanceBatch(
    Logger logger,
    address spokeProxyAdminOwner,
    address authority,
    bytes memory spokeBytecode,
    uint8 oracleDecimals,
    string memory oracleDescription,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.log('...Deploying AaveV4SpokeInstanceBatch...');
    report = AaveV4DeployBase.deploySpokeInstanceBatch({
      spokeProxyAdminOwner: spokeProxyAdminOwner,
      authority: authority,
      spokeBytecode: spokeBytecode,
      oracleDecimals: oracleDecimals,
      oracleDescription: oracleDescription,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });
    return report;
  }

  function _deployHubBatch(
    Logger logger,
    address treasurySpokeOwner,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (BatchReports.HubBatchReport memory report) {
    logger.log('...Deploying HubBatch...');
    report = AaveV4DeployBase.deployHubBatch({
      treasurySpokeOwner: treasurySpokeOwner,
      authority: authority,
      hubBytecode: hubBytecode,
      salt: salt
    });
    return report;
  }

  function _deployGatewayBatch(
    Logger logger,
    address gatewayOwner,
    address nativeWrapper,
    bool deployNativeTokenGateway,
    bool deploySignatureGateway,
    bytes32 salt
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.log('...Deploying GatewayBatch...');
    report = AaveV4DeployBase.deployGatewaysBatch({
      owner: gatewayOwner,
      nativeWrapper: nativeWrapper,
      deployNativeTokenGateway: deployNativeTokenGateway,
      deploySignatureGateway: deploySignatureGateway,
      salt: salt
    });
    if (deployNativeTokenGateway) {
      logger.log('NativeTokenGateway', report.nativeGateway);
    }
    if (deploySignatureGateway) {
      logger.log('SignatureGateway', report.signatureGateway);
    }
    return report;
  }

  function _logSpokeReport(
    Logger logger,
    BatchReports.SpokeInstanceBatchReport memory report,
    string memory label
  ) internal pure {
    logger.log(label);
    logger.log('  SpokeInstance Proxy', report.spokeProxy);
    logger.log('  SpokeInstance Implementation', report.spokeImplementation);
    logger.log('  AaveOracle', report.aaveOracle);
  }

  function _setupSpokeRoles(
    Logger logger,
    BatchReports.SpokeInstanceBatchReport memory report,
    address authority
  ) internal {
    logger.log('...Setting Spoke roles...');
    AaveV4SpokeRolesProcedure.setupSpokeRoles(authority, report.spokeProxy);
  }

  function _logHubReport(
    Logger logger,
    BatchReports.HubBatchReport memory report,
    string memory label
  ) internal pure {
    logger.log(label);
    logger.log('  Hub', report.hub);
    logger.log('  InterestRateStrategy', report.irStrategy);
    logger.log('  TreasurySpoke', report.treasurySpoke);
  }

  function _setupHubRoles(
    Logger logger,
    BatchReports.HubBatchReport memory report,
    address authority
  ) internal {
    logger.log('...Setting Hub roles...');
    AaveV4HubRolesProcedure.setupHubRoles(authority, report.hub);
  }

  function _deriveSalt(bytes32 salt_) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked(SALT, salt_));
  }
}
