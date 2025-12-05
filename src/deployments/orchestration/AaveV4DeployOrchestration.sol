// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {IProgressLogger} from 'src/deployments/utils/interfaces/IProgressLogger.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';

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
  bool public constant IS_TEST = true;
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
    bool setRoles
  ) internal returns (OrchestrationReports.FullDeploymentReport memory) {
    OrchestrationReports.FullDeploymentReport memory report;

    // Deploy Access Batch
    address accessManagerAdmin = setRoles ? deployer : admin;
    report.accessBatchReport = _deployAccessBatch(logger, deployer, accessManagerAdmin);

    // Deploy Configurator Batch
    report.configuratorBatchReport = _deployConfiguratorBatch(logger, deployer, admin);

    // Deploy Hub Batches
    report.hubBatchReports = _deployHubs(
      logger,
      deployer,
      admin,
      report.accessBatchReport.accessManagerAddress,
      hubLabels,
      setRoles
    );

    // Deploy Spoke Instance Batches
    report.spokeInstanceBatchReports = _deploySpokes(
      logger,
      deployer,
      admin,
      report.accessBatchReport.accessManagerAddress,
      spokeLabels,
      setRoles
    );

    // Deploy Gateways Batch
    report.gatewaysBatchReport = _deployGatewayBatch(logger, deployer, admin, nativeWrapper);

    // Set Roles if needed
    if (setRoles) {
      logger.log('...Setting Configurator roles...');
      AaveV4AdminRolesProcedure.setConfiguratorAdminRoles(
        report.accessBatchReport.accessManagerAddress,
        report.configuratorBatchReport.spokeConfiguratorAddress,
        report.configuratorBatchReport.hubConfiguratorAddress
      );

      logger.log('...Setting AccessManager Root Admin role...');
      AaveV4AdminRolesProcedure.setAccessManagerRootAdminRole(
        report.accessBatchReport.accessManagerAddress,
        admin,
        deployer
      );
    }

    return report;
  }

  function _deployAccessBatch(
    IProgressLogger logger,
    address deployer,
    address admin
  ) internal returns (BatchReports.AccessBatchReport memory report) {
    logger.log('...Deploying AccessBatch...');

    if (!IS_TEST) vm.broadcast(deployer);
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin);

    report = accessBatch.getReport();
    logger.log('AccessManager', report.accessManagerAddress);
    logger.log('');
    return report;
  }

  function _deployConfiguratorBatch(
    IProgressLogger logger,
    address deployer,
    address admin
  ) internal returns (BatchReports.ConfiguratorBatchReport memory report) {
    logger.log('...Deploying ConfiguratorBatch...');

    if (!IS_TEST) vm.broadcast(deployer);
    AaveV4ConfiguratorBatch configuratorBatch = new AaveV4ConfiguratorBatch(admin);

    report = configuratorBatch.getReport();
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
    bool setRoles
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
        setRoles
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
    bool setRoles
  ) internal returns (OrchestrationReports.HubDeploymentReport memory) {
    OrchestrationReports.HubDeploymentReport memory hubReport;
    hubReport.label = label;
    hubReport.report = _deployHubBatch(logger, deployer, admin, accessManagerAddress);

    logger.log(label);
    logger.log('  Hub', hubReport.report.hubAddress);
    logger.log('  InterestRateStrategy', hubReport.report.irStrategyAddress);
    logger.log('  TreasurySpoke', hubReport.report.treasurySpokeAddress);

    // Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](3);
    // hubEntries[0] = Logger.AddressEntry({label: 'Hub', value: hubReport.report.hubAddress});
    // hubEntries[1] = Logger.AddressEntry({
    //   label: 'InterestRateStrategy',
    //   value: hubReport.report.irStrategyAddress
    // });
    // hubEntries[2] = Logger.AddressEntry({
    //   label: 'TreasurySpoke',
    //   value: hubReport.report.treasurySpokeAddress
    // });

    // logger.writeGroup(label, hubEntries);

    if (setRoles) {
      logger.log('...Setting Hub roles...');
      AaveV4HubRolesProcedure.setHubRoles(accessManagerAddress, hubReport.report.hubAddress);
    }

    return hubReport;
  }

  function _deploySpokes(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string[] memory spokeLabels,
    bool setRoles
  ) internal returns (OrchestrationReports.SpokeDeploymentReport[] memory spokeBatchReports) {
    uint256 spokeCount = spokeLabels.length;
    spokeBatchReports = new OrchestrationReports.SpokeDeploymentReport[](spokeCount);
    // Logger.AddressEntry[] memory spokeEntries = new Logger.AddressEntry[](spokeCount);
    for (uint256 i; i < spokeCount; ++i) {
      spokeBatchReports[i] = _deploySpoke(
        logger,
        deployer,
        admin,
        accessManagerAddress,
        spokeLabels[i],
        setRoles
      );
      // spokeEntries[i] = Logger.AddressEntry({
      //   label: spokeLabels[i],
      //   value: spokeBatchReports[i].report.spokeProxyAddress
      // });
    }
    // logger.writeGroup('SpokeInstances', spokeEntries);
    logger.log('');
    return spokeBatchReports;
  }

  function _deploySpoke(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label,
    bool setRoles
  ) internal returns (OrchestrationReports.SpokeDeploymentReport memory) {
    OrchestrationReports.SpokeDeploymentReport memory spokeReport;

    spokeReport.label = label;
    spokeReport.report = _deploySpokeInstanceBatch(
      logger,
      deployer,
      admin,
      accessManagerAddress,
      label
    );

    logger.log(label);
    logger.log('  SpokeInstance Proxy', spokeReport.report.spokeProxyAddress);
    logger.log('  SpokeInstance Implementation', spokeReport.report.spokeImplementationAddress);
    logger.log('  AaveOracle', spokeReport.report.aaveOracleAddress);

    if (setRoles) {
      logger.log('...Setting Spoke roles...');
      AaveV4SpokeRolesProcedure.setSpokeRoles(
        accessManagerAddress,
        spokeReport.report.spokeProxyAddress
      );
    }

    return spokeReport;
  }

  function _deployHubBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress
  ) internal returns (BatchReports.HubBatchReport memory) {
    logger.log('...Deploying HubBatch...');

    if (!IS_TEST) vm.broadcast(deployer);
    AaveV4HubBatch hubBatch = new AaveV4HubBatch(admin, accessManagerAddress);

    return hubBatch.getReport();
  }

  function _deploySpokeInstanceBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    address accessManagerAddress,
    string memory label
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    logger.log('...Deploying AaveV4SpokeInstanceBatch...');

    if (!IS_TEST) vm.broadcast(deployer);
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch(
      admin,
      accessManagerAddress,
      ORACLE_DECIMALS,
      string.concat(label, ORACLE_SUFFIX)
    );

    return spokeInstanceBatch.getReport();
  }

  function _deployGatewayBatch(
    IProgressLogger logger,
    address deployer,
    address admin,
    address nativeWrapper
  ) internal returns (BatchReports.GatewaysBatchReport memory report) {
    logger.log('...Deploying GatewayBatch...');

    if (!IS_TEST) vm.broadcast(deployer);
    AaveV4GatewayBatch gatewayBatch = new AaveV4GatewayBatch(admin, nativeWrapper);

    report = gatewayBatch.getReport();
    logger.log('NativeTokenGateway', report.nativeGatewayAddress);
    logger.log('SignatureGateway', report.signatureGatewayAddress);
    return report;
  }
}
