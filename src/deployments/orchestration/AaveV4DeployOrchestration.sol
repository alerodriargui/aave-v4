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
import {AaveV4PositionManagerBatch} from 'src/deployments/batches/AaveV4PositionManagerBatch.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

library AaveV4DeployOrchestration {
  bytes32 public constant SALT = keccak256('AAVE_V4');

  uint8 public constant SPOKE_ORACLE_DECIMALS = 8;

  function deployAaveV4(
    Logger logger,
    address deployer,
    InputUtils.FullDeployInputs memory deployInputs,
    bytes memory hubBytecode,
    bytes memory spokeBytecode
  ) internal returns (OrchestrationReports.FullDeploymentReport memory report) {
    bytes32 salt = _deriveSalt(deployInputs.salt);
    report.salt = deployInputs.salt;

    // Deploy Access Batch
    // initialize with deployer as access manager admin
    address initialAdmin = deployer;
    report.authorityBatchReport = _deployAuthorityBatch({
      logger: logger,
      accessManagerAdmin: initialAdmin,
      salt: salt
    });

    address accessManager = report.authorityBatchReport.accessManager;

    // Deploy Configurator Batch with AccessManager as authority
    report.configuratorBatchReport = _deployConfiguratorBatch({
      logger: logger,
      hubConfiguratorAuthority: accessManager,
      spokeConfiguratorAuthority: accessManager,
      salt: salt
    });

    // Setup Configurator Roles
    logger.logHeader1('Setting HubConfigurator roles');
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles({
      accessManager: accessManager,
      hubConfigurator: report.configuratorBatchReport.hubConfigurator
    });
    logger.logHeader1('Setting SpokeConfigurator roles');
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      spokeConfigurator: report.configuratorBatchReport.spokeConfigurator
    });

    // Deploy TreasurySpoke Batch (single instance for all hubs)
    report.treasurySpokeBatchReport = _deployTreasurySpokeBatch({
      logger: logger,
      treasurySpokeOwner: deployInputs.treasurySpokeOwner,
      salt: salt
    });

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs({
      logger: logger,
      authority: accessManager,
      hubLabels: deployInputs.hubLabels,
      hubBytecode: hubBytecode,
      salt: salt
    });

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes({
      logger: logger,
      authority: accessManager,
      inputs: deployInputs,
      spokeBytecode: spokeBytecode,
      salt: salt
    });

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

    // Deploy Position Managers Batch if flag is enabled
    if (deployInputs.deployPositionManagers) {
      report.positionManagerBatchReport = _deployPositionManagerBatch({
        logger: logger,
        positionManagerOwner: deployInputs.positionManagerOwner,
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
        logger.logHeader1('Granting AccessManager Root Admin role');
        AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
          accessManager: accessManager,
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
    address accessManager = report.authorityBatchReport.accessManager;

    logger.logHeader1('Granting Hub Admin role');
    AaveV4HubRolesProcedure.grantHubAllRoles({accessManager: accessManager, admin: hubAdmin});

    logger.logHeader1('Granting Hub Configurator roles');
    AaveV4HubRolesProcedure.grantHubRole({
      accessManager: accessManager,
      role: Roles.HUB_CONFIGURATOR_ROLE,
      admin: report.configuratorBatchReport.hubConfigurator
    });

    logger.logHeader1('Granting HubConfigurator Admin roles');
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
      accessManager: accessManager,
      admin: hubConfiguratorAdmin
    });
  }

  function _grantSpokeRoles(
    Logger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    address spokeAdmin,
    address spokeConfiguratorAdmin
  ) internal {
    address accessManager = report.authorityBatchReport.accessManager;

    logger.logHeader1('Granting Spoke Admin role');
    AaveV4SpokeRolesProcedure.grantSpokeAllRoles({accessManager: accessManager, admin: spokeAdmin});

    logger.logHeader1('Granting Spoke Configurator roles');
    AaveV4SpokeRolesProcedure.grantSpokeRole({
      accessManager: accessManager,
      role: Roles.SPOKE_CONFIGURATOR_ROLE,
      admin: report.configuratorBatchReport.spokeConfigurator
    });

    logger.logHeader1('Granting SpokeConfigurator Admin roles');
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
      accessManager: accessManager,
      admin: spokeConfiguratorAdmin
    });
  }

  function _deployAuthorityBatch(
    Logger logger,
    address accessManagerAdmin,
    bytes32 salt
  ) internal returns (BatchReports.AuthorityBatchReport memory report) {
    logger.logHeader1('Deploying AuthorityBatch');

    report = AaveV4DeployBase.deployAuthorityBatch({admin: accessManagerAdmin, salt: salt});

    logger.log('AccessManager', report.accessManager);
    logger.logNewLine();
    return report;
  }

  function _deployConfiguratorBatch(
    Logger logger,
    address hubConfiguratorAuthority,
    address spokeConfiguratorAuthority,
    bytes32 salt
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.logHeader1('Deploying ConfiguratorBatch');

    report = AaveV4DeployBase.deployConfiguratorBatch({
      hubConfiguratorAuthority: hubConfiguratorAuthority,
      spokeConfiguratorAuthority: spokeConfiguratorAuthority,
      salt: salt
    });

    logger.log('HubConfigurator', report.hubConfigurator);
    logger.log('SpokeConfigurator', report.spokeConfigurator);
    logger.logNewLine();
    return report;
  }

  function _deployHubs(
    Logger logger,
    address authority,
    string[] memory hubLabels,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport[] memory hubBatchReports) {
    uint256 hubCount = hubLabels.length;
    hubBatchReports = new OrchestrationReports.HubDeploymentReport[](hubCount);
    for (uint256 i; i < hubCount; ++i) {
      bytes32 childSalt = _deriveChildSalt(salt, 'hub', hubLabels[i]);
      hubBatchReports[i] = _deployHub({
        logger: logger,
        authority: authority,
        label: hubLabels[i],
        hubBytecode: hubBytecode,
        salt: childSalt
      });
    }
    logger.logNewLine();
    return hubBatchReports;
  }

  function _deployHub(
    Logger logger,
    address authority,
    string memory label,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch({
      logger: logger,
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
    require(
      spokeCount == inputs.spokeMaxReservesLimits.length,
      'spoke labels/limits length mismatch'
    );
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      bytes32 childSalt = _deriveChildSalt(salt, 'spoke', inputs.spokeLabels[i]);
      spokeBatchReports[i] = _deploySpoke({
        logger: logger,
        spokeProxyAdminOwner: inputs.spokeProxyAdminOwner,
        authority: authority,
        label: inputs.spokeLabels[i],
        spokeBytecode: spokeBytecode,
        maxUserReservesLimit: inputs.spokeMaxReservesLimits[i],
        oracleDecimals: SPOKE_ORACLE_DECIMALS,
        salt: childSalt
      });
    }
    logger.logNewLine();
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
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory report) {
    logger.logHeader1('Deploying AaveV4SpokeInstanceBatch');
    report = AaveV4DeployBase.deploySpokeInstanceBatch({
      spokeProxyAdminOwner: spokeProxyAdminOwner,
      authority: authority,
      spokeBytecode: spokeBytecode,
      oracleDecimals: oracleDecimals,
      maxUserReservesLimit: maxUserReservesLimit,
      salt: salt
    });
    return report;
  }

  function _deployTreasurySpokeBatch(
    Logger logger,
    address treasurySpokeOwner,
    bytes32 salt
  ) internal returns (BatchReports.TreasurySpokeBatchReport memory report) {
    logger.logHeader1('Deploying TreasurySpokeBatch');
    report = AaveV4DeployBase.deployTreasurySpokeBatch({owner: treasurySpokeOwner, salt: salt});
    logger.log('TreasurySpoke', report.treasurySpoke);
    logger.logNewLine();
    return report;
  }

  function _deployHubBatch(
    Logger logger,
    address authority,
    bytes memory hubBytecode,
    bytes32 salt
  ) internal returns (BatchReports.HubBatchReport memory report) {
    logger.logHeader1('Deploying HubBatch');
    report = AaveV4DeployBase.deployHubBatch({
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
    logger.logHeader1('Deploying GatewayBatch');
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

  function _deployPositionManagerBatch(
    Logger logger,
    address positionManagerOwner,
    bytes32 salt
  ) internal returns (BatchReports.PositionManagerBatchReport memory report) {
    logger.logHeader1('Deploying PositionManagerBatch');
    report = AaveV4DeployBase.deployPositionManagerBatch({owner: positionManagerOwner, salt: salt});
    logger.logDetail('GiverPositionManager', report.giverPositionManager);
    logger.logDetail('TakerPositionManager', report.takerPositionManager);
    logger.logDetail('ConfigPositionManager', report.configPositionManager);
    return report;
  }

  function _logSpokeReport(
    Logger logger,
    BatchReports.SpokeInstanceBatchReport memory report,
    string memory label
  ) internal pure {
    logger.log(label);
    logger.logDetail('SpokeInstance Proxy', report.spokeProxy);
    logger.logDetail('SpokeInstance Implementation', report.spokeImplementation);
    logger.logDetail('AaveOracle', report.aaveOracle);
  }

  function _setupSpokeRoles(
    Logger logger,
    BatchReports.SpokeInstanceBatchReport memory report,
    address authority
  ) internal {
    logger.logHeader1('Setting Spoke roles');
    AaveV4SpokeRolesProcedure.setupSpokeAllRoles(authority, report.spokeProxy);
  }

  function _logHubReport(
    Logger logger,
    BatchReports.HubBatchReport memory report,
    string memory label
  ) internal pure {
    logger.log(label);
    logger.logDetail('Hub', report.hub);
    logger.logDetail('InterestRateStrategy', report.irStrategy);
  }

  function _setupHubRoles(
    Logger logger,
    BatchReports.HubBatchReport memory report,
    address authority
  ) internal {
    logger.logHeader1('Setting Hub roles');
    AaveV4HubRolesProcedure.setupHubAllRoles(authority, report.hub);
  }

  function _deriveSalt(bytes32 salt_) internal pure returns (bytes32) {
    return keccak256(abi.encode(SALT, salt_));
  }

  function _deriveChildSalt(
    bytes32 baseSalt,
    string memory kind,
    string memory label
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(baseSalt, kind, label));
  }
}
