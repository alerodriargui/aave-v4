// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';

import {ConfigReader} from 'scripts/ConfigReader.sol';
import {SpokeDeployUtils} from 'scripts/SpokeDeployUtils.sol';
import {AaveV4HubDeployHelper} from 'scripts/deploy/helpers/AaveV4HubDeployHelper.sol';
import {AaveV4SpokeDeployHelper} from 'scripts/deploy/helpers/AaveV4SpokeDeployHelper.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {AaveV4DeployOrchestration} from 'src/deployments/orchestration/AaveV4DeployOrchestration.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

/// @title AaveV4FullDeployScript
/// @notice Deploy script that reads a unified JSON config and:
///   1. Deploys all contracts via AaveV4DeployOrchestration (if hubs/spokes are defined)
///   2. Lists assets on hubs via HubConfigEngine (if assets are defined)
///   3. Registers spokes on hubs via HubConfigEngine (if spokeRegistrations are defined)
///   4. Configures reserves on spokes via SpokeConfigEngine (if reserves are defined)
///   5. Grants permanent roles and transfers admin to the final admin address
///
///   Each step is conditional — if the JSON section is empty, that step is skipped.
///   Admin handoff is deferred until after all config engine operations complete.
///   If no config engine operations are needed, handoff happens right after contract deployment.
///
///   Hub-side and spoke-side logic is inherited from AaveV4HubDeployHelper and
///   AaveV4SpokeDeployHelper respectively, which can also be used independently
///   for partial deployments (e.g., adding spokes to an existing hub).
contract AaveV4FullDeployScript is
  Script,
  InputUtils,
  AaveV4HubDeployHelper,
  AaveV4SpokeDeployHelper
{
  using ConfigReader for string;

  string internal constant OUTPUT_DIR = 'output/reports/deployments/';

  string internal _configPath;
  string internal _outputFileName;

  constructor(string memory configPath_, string memory outputFileName_) {
    _configPath = configPath_;
    _outputFileName = outputFileName_;
  }

  function run() external {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);

    string memory json = vm.readFile(_configPath);
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();

    (, address deployer, ) = vm.readCallers();

    logger.log('CHAIN ID', block.chainid);
    logger.log('Config', _configPath);

    // ==================== Step 1: Deploy contracts ====================
    // Deployer retains DEFAULT_ADMIN_ROLE throughout. Roles are granted
    // explicitly at the end once all config engine operations are complete.

    uint256 hubCount;
    while (json.hubExists(hubCount)) {
      hubCount++;
    }
    uint256 spokeCount;
    while (json.spokeExists(spokeCount)) {
      spokeCount++;
    }

    OrchestrationReports.FullDeploymentReport memory report;
    bool didDeploy = hubCount > 0 || spokeCount > 0;

    // Count config engine items upfront to determine handoff timing
    uint256 assetCount;
    while (json.assetExists(assetCount)) {
      assetCount++;
    }
    uint256 spokeRegistrationCount;
    while (json.spokeRegistrationExists(spokeRegistrationCount)) {
      spokeRegistrationCount++;
    }
    uint256 reserveCount;
    while (json.reserveExists(reserveCount)) {
      reserveCount++;
    }

    bool needsConfigEngine = assetCount > 0 || spokeRegistrationCount > 0 || reserveCount > 0;

    if (didDeploy) {
      // Verify LiquidationLogic is linked when deploying spokes.
      // Run `forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi` first.
      if (spokeCount > 0) {
        _requireLiquidationLogicLinked();
      }

      // If config engine ops are needed, defer role grants (deployer stays admin).
      // If NOT needed, grant roles immediately during deploy (handoff in orchestration).
      InputUtils.FullDeployInputs memory inputs = _buildDeployInputs(
        json,
        infra,
        hubCount,
        spokeCount,
        !needsConfigEngine // grantRoles: true only if no config engine ops
      );

      logger.log('...Starting Aave V4 Contract Deployment...');
      vm.startBroadcast(deployer);

      report = AaveV4DeployOrchestration.deployAaveV4(logger, deployer, inputs);

      // If no config engine ops, handoff already happened in orchestration — done.
      if (!needsConfigEngine) {
        vm.stopBroadcast();
        logger.writeJsonReportMarket(report);
        _writeAdminInfo(logger, infra);
        logger.log('...Full Deployment Completed (no config engine ops)...');
        logger.save({fileName: _outputFileName, withTimestamp: true});
        return;
      }

      // Config engine ops needed — deployer still has DEFAULT_ADMIN_ROLE.
      // Grant configurator contract roles so config engine path works:
      //   ConfigEngine → HubConfigurator → Hub  (needs HUB_CONFIGURATOR_ROLE on HubConfigurator contract)
      //   ConfigEngine → SpokeConfigurator → Spoke  (needs SPOKE_CONFIGURATOR_ROLE on SpokeConfigurator contract)
      address accessManager = report.accessBatchReport.accessManager;
      _grantConfiguratorContractRoles(logger, report);

      // Continue broadcast for config steps below
    } else {
      logger.log('No hubs or spokes to deploy, skipping contract deployment');
      vm.startBroadcast(deployer);
    }

    // ==================== Step 2: List assets on hubs ====================

    if (assetCount > 0 && hubCount > 0) {
      logger.log('...Listing assets on hubs...');
      _listAssets(json, infra, report, assetCount, hubCount);
    }

    // ==================== Step 3: Register spokes on hubs ====================

    if (spokeRegistrationCount > 0 && hubCount > 0) {
      logger.log('...Registering spokes on hubs...');
      _registerSpokes(json, infra, report, spokeRegistrationCount, hubCount, spokeCount);
    }

    // ==================== Step 4: Configure reserves on spokes ====================

    if (reserveCount > 0 && spokeCount > 0) {
      logger.log('...Configuring reserves on spokes...');
      _configureReserves(json, report, reserveCount, spokeCount, hubCount);
    }

    // ==================== Step 5: Grant permanent roles + admin handoff ====================

    if (didDeploy) {
      logger.log('...Granting permanent roles and transferring admin...');
      _grantPermanentRolesAndHandoff(logger, report, infra, deployer, hubCount, spokeCount);
    }

    vm.stopBroadcast();

    // ==================== Write output ====================

    if (didDeploy) {
      logger.writeJsonReportMarket(report);
    }
    _writeAdminInfo(logger, infra);
    logger.log('...Full Deployment Completed...');
    logger.save({fileName: _outputFileName, withTimestamp: true});
  }

  // ==================== Internal: Deploy Inputs ====================

  function _buildDeployInputs(
    string memory json,
    ConfigReader.InfrastructureConfig memory infra,
    uint256 hubCount,
    uint256 spokeCount,
    bool grantRoles
  ) internal view returns (InputUtils.FullDeployInputs memory inputs) {
    string[] memory hubLabels = new string[](hubCount);
    for (uint256 i; i < hubCount; i++) {
      hubLabels[i] = json.hubKey(i);
    }

    string[] memory spokeLabels = new string[](spokeCount);
    for (uint256 i; i < spokeCount; i++) {
      spokeLabels[i] = json.spokeKey(i);
    }

    inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: infra.accessManagerAdmin,
      hubAdmin: infra.hubConfiguratorAdmin,
      hubConfiguratorAdmin: infra.hubConfiguratorAdmin,
      treasurySpokeOwner: infra.treasurySpokeOwner,
      spokeAdmin: infra.spokeConfiguratorAdmin,
      spokeProxyAdminOwner: infra.spokeProxyAdminOwner,
      spokeConfiguratorAdmin: infra.spokeConfiguratorAdmin,
      gatewayOwner: infra.gatewayOwner,
      nativeWrapper: infra.nativeWrapper,
      grantRoles: grantRoles,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      salt: keccak256(bytes(infra.salt))
    });
  }

  // ==================== Internal: Configurator Contract Roles ====================

  /// @dev Grants roles that allow Configurator contracts to call Hub/Spoke.
  ///      These are needed for the config engine call path to work:
  ///      ConfigEngine → HubConfigurator (needs role 9) → Hub (HubConfigurator has role 5)
  ///      ConfigEngine → SpokeConfigurator (needs role 13) → Spoke (SpokeConfigurator has role 6)
  function _grantConfiguratorContractRoles(
    MetadataLogger logger,
    OrchestrationReports.FullDeploymentReport memory report
  ) internal {
    address accessManager = report.accessBatchReport.accessManager;

    // HubConfigurator needs HUB_CONFIGURATOR_ROLE to call Hub functions
    logger.log('...Granting Hub Configurator contract role...');
    AaveV4HubRolesProcedure.grantHubConfiguratorRole({
      accessManager: accessManager,
      admin: report.configuratorBatchReport.hubConfigurator
    });

    // SpokeConfigurator needs SPOKE_CONFIGURATOR_ROLE to call Spoke functions
    logger.log('...Granting Spoke Configurator contract role...');
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      admin: report.configuratorBatchReport.spokeConfigurator
    });
  }

  // ==================== Internal: Permanent Role Grants + Handoff ====================

  /// @dev Grants permanent roles to the admin addresses from config and
  ///      transfers DEFAULT_ADMIN_ROLE from deployer to the final admin.
  function _grantPermanentRolesAndHandoff(
    MetadataLogger logger,
    OrchestrationReports.FullDeploymentReport memory report,
    ConfigReader.InfrastructureConfig memory infra,
    address deployer,
    uint256 hubCount,
    uint256 spokeCount
  ) internal {
    address accessManager = report.accessBatchReport.accessManager;

    // Grant hub admin roles
    if (hubCount > 0) {
      logger.log('...Granting Hub Admin role...');
      AaveV4HubRolesProcedure.grantHubAdminRole({
        accessManager: accessManager,
        admin: infra.hubConfiguratorAdmin
      });

      logger.log('...Granting HubConfigurator Admin roles...');
      AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles({
        accessManager: accessManager,
        admin: infra.hubConfiguratorAdmin
      });
    }

    // Grant spoke admin roles
    if (spokeCount > 0) {
      logger.log('...Granting Spoke Admin role...');
      AaveV4SpokeRolesProcedure.grantSpokeAdminRole({
        accessManager: accessManager,
        admin: infra.spokeConfiguratorAdmin
      });

      logger.log('...Granting SpokeConfigurator Admin roles...');
      AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles({
        accessManager: accessManager,
        admin: infra.spokeConfiguratorAdmin
      });
    }

    // Transfer DEFAULT_ADMIN_ROLE from deployer to final admin
    if (infra.accessManagerAdmin != deployer) {
      logger.log('...Transferring DEFAULT_ADMIN_ROLE to final admin...');
      logger.log('Final Admin', infra.accessManagerAdmin);
      AaveV4AccessManagerRolesProcedure.replaceDefaultAdminRole({
        accessManager: accessManager,
        adminToAdd: infra.accessManagerAdmin,
        adminToRemove: deployer
      });
    }
  }

  // ==================== Internal: Library Linking Check ====================

  /// @dev Verifies that LiquidationLogic has been pre-deployed and FOUNDRY_LIBRARIES is set.
  ///      SpokeInstance (via-ir compiled) links LiquidationLogic as an external library.
  ///      Without FOUNDRY_LIBRARIES, vm.getCode('SpokeInstance') returns unlinked bytecode
  ///      with placeholder bytes, resulting in a non-functional contract.
  function _requireLiquidationLogicLinked() internal {
    bool envExists = SpokeDeployUtils._librariesPathExists();
    require(
      envExists,
      'FOUNDRY_LIBRARIES not set. Run: forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi'
    );

    address lib = SpokeDeployUtils._getLiquidationLogicAddress();
    require(
      lib != address(0) && lib.code.length > 0,
      'LiquidationLogic not deployed. Run LibraryPreCompile first.'
    );
  }

  // ==================== Internal: Output ====================

  /// @dev Writes admin-related info to the deploy output JSON.
  function _writeAdminInfo(
    MetadataLogger logger,
    ConfigReader.InfrastructureConfig memory infra
  ) internal {
    logger.write('FinalAdmin', infra.accessManagerAdmin);
    logger.write('HubConfiguratorAdmin', infra.hubConfiguratorAdmin);
    logger.write('SpokeConfiguratorAdmin', infra.spokeConfiguratorAdmin);
  }
}

/// @notice Default concrete deploy script reading from config/deploy.json
contract AaveV4FullDeployDefaultScript is AaveV4FullDeployScript {
  constructor() AaveV4FullDeployScript('config/deploy.json', 'AaveV4FullDeploy.json') {}
}
