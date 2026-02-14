// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'scripts/deploy/AaveV4DeployBatchBase.s.sol';

import 'scripts/deploy/helpers/AaveV4HubDeployHelper.sol';
import 'scripts/deploy/helpers/AaveV4SpokeDeployHelper.sol';

import {SpokeDeployUtils} from 'scripts/SpokeDeployUtils.sol';
import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

/// @title AaveV4FullDeployScript
/// @notice Deploy script that reads a unified JSON config and:
///   1. Deploys all contracts via AaveV4DeployOrchestration (if hubs/spokes are defined)
///   2. Lists assets on hubs via HubConfigurator (if assets are defined)
///   3. Registers spokes on hubs via HubConfigurator (if spokeRegistrations are defined)
///   4. Configures reserves on spokes via SpokeConfigurator (if reserves are defined)
///   5. Grants permanent roles and transfers admin to the final admin address
///
///   Each step is conditional — if the JSON section is empty, that step is skipped.
///   Follows V3 pattern: deployer gets temporary admin roles to call configurators
///   directly during the config phase, then those roles are revoked before handoff.
///
///   Hub-side and spoke-side logic is inherited from AaveV4HubDeployHelper and
///   AaveV4SpokeDeployHelper respectively, which can also be used independently
///   for partial deployments (e.g., adding spokes to an existing hub).
contract AaveV4FullDeployScript is
  AaveV4DeployBatchBaseScript,
  AaveV4HubDeployHelper,
  AaveV4SpokeDeployHelper
{
  using ConfigReader for string;

  constructor(
    string memory inputFileName_,
    string memory outputFileName_
  ) AaveV4DeployBatchBaseScript(inputFileName_, outputFileName_) {}

  function run() external override {
    vm.createDir(OUTPUT_DIR, true);
    MetadataLogger logger = new MetadataLogger(OUTPUT_DIR);

    string memory json = vm.readFile(string.concat(INPUT_PATH, _inputFileName));
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();

    (, address deployer, ) = vm.readCallers();

    logger.log('CHAIN ID', block.chainid);
    logger.log('Config', string.concat(INPUT_PATH, _inputFileName));

    // ==================== Step 1: Deploy contracts ====================
    // Deployer retains DEFAULT_ADMIN_ROLE throughout. Roles are granted
    // explicitly at the end once all configuration operations are complete.

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

    // Count config items upfront to determine handoff timing
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

    bool needsConfig = assetCount > 0 || spokeRegistrationCount > 0 || reserveCount > 0;

    if (didDeploy) {
      // Verify LiquidationLogic is linked when deploying spokes.
      // Run `forge script scripts/LibraryPreCompile.s.sol --broadcast --fork-url $RPC --ffi` first.
      if (spokeCount > 0) {
        _requireLiquidationLogicLinked();
      }

      // If config ops are needed, defer role grants (deployer stays admin).
      // If NOT needed, grant roles immediately during deploy (handoff in orchestration).
      FullDeployInputs memory inputs = _buildDeployInputs(
        json,
        infra,
        hubCount,
        spokeCount,
        !needsConfig // grantRoles: true only if no config ops
      );

      logger.log('...Starting Aave V4 Contract Deployment...');
      vm.startBroadcast(deployer);

      report = AaveV4DeployOrchestration.deployAaveV4(
        logger,
        deployer,
        inputs,
        _getHubBytecode(),
        _getSpokeBytecode()
      );

      // If no config ops, handoff already happened in orchestration — done.
      if (!needsConfig) {
        vm.stopBroadcast();
        logger.writeJsonReportMarket(report);
        _writeAdminInfo(logger, infra);
        logger.log('...Full Deployment Completed (no config ops)...');
        logger.log('...Saving Logs...');
        logger.save({fileName: _outputFileName, withTimestamp: true});
        return;
      }

      // Config ops needed — deployer still has DEFAULT_ADMIN_ROLE.
      // Grant structural configurator contract roles (HubConfigurator→role 5, SpokeConfigurator→role 6)
      // and temporary deployer admin roles for the config phase.
      address accessManager = report.accessBatchReport.accessManager;
      _grantConfiguratorContractRoles(logger, report);
      _grantDeployerTempRoles(
        logger,
        IAccessManager(accessManager),
        deployer,
        hubCount,
        spokeCount
      );

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

    // ==================== Step 5: Revoke deployer temp roles + permanent handoff ====================

    if (didDeploy) {
      address accessManager = report.accessBatchReport.accessManager;
      _revokeDeployerTempRoles(
        logger,
        IAccessManager(accessManager),
        deployer,
        hubCount,
        spokeCount
      );

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
    logger.log('...Saving Logs...');
    logger.save({fileName: _outputFileName, withTimestamp: true});
  }

  // ==================== Internal: Configurator Contract Roles ====================

  /// @dev Grants structural roles that allow Configurator contracts to call Hub/Spoke.
  ///      HubConfigurator needs HUB_CONFIGURATOR_ROLE (5) to call Hub functions.
  ///      SpokeConfigurator needs SPOKE_CONFIGURATOR_ROLE (6) to call Spoke functions.
  function _grantConfiguratorContractRoles(
    MetadataLogger logger,
    OrchestrationReports.FullDeploymentReport memory report
  ) internal {
    address accessManager = report.accessBatchReport.accessManager;

    logger.log('...Granting Hub Configurator contract role...');
    AaveV4HubRolesProcedure.grantHubConfiguratorRole({
      accessManager: accessManager,
      admin: report.configuratorBatchReport.hubConfigurator
    });

    logger.log('...Granting Spoke Configurator contract role...');
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole({
      accessManager: accessManager,
      admin: report.configuratorBatchReport.spokeConfigurator
    });
  }

  // ==================== Internal: Deployer Temporary Roles ====================

  /// @dev Grants the deployer temporary admin roles on the configurators so it can
  ///      call HubConfigurator/SpokeConfigurator directly during the config phase.
  ///      These roles are revoked after configuration is complete (V3 pattern).
  function _grantDeployerTempRoles(
    MetadataLogger logger,
    IAccessManager accessManager,
    address deployer,
    uint256 hubCount,
    uint256 spokeCount
  ) internal {
    logger.log('...Granting deployer temporary configurator admin roles...');
    if (hubCount > 0) {
      accessManager.grantRole(Roles.HUB_CONFIGURATOR_ADMIN_ROLE, deployer, 0);
    }
    if (spokeCount > 0) {
      accessManager.grantRole(Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE, deployer, 0);
      accessManager.grantRole(Roles.SPOKE_FREEZE_ROLE, deployer, 0);
      accessManager.grantRole(Roles.SPOKE_PAUSE_ROLE, deployer, 0);
    }
  }

  /// @dev Revokes the deployer's temporary admin roles after configuration is complete.
  function _revokeDeployerTempRoles(
    MetadataLogger logger,
    IAccessManager accessManager,
    address deployer,
    uint256 hubCount,
    uint256 spokeCount
  ) internal {
    logger.log('...Revoking deployer temporary configurator admin roles...');
    if (hubCount > 0) {
      accessManager.revokeRole(Roles.HUB_CONFIGURATOR_ADMIN_ROLE, deployer);
    }
    if (spokeCount > 0) {
      accessManager.revokeRole(Roles.SPOKE_CONFIGURATOR_ADMIN_ROLE, deployer);
      accessManager.revokeRole(Roles.SPOKE_FREEZE_ROLE, deployer);
      accessManager.revokeRole(Roles.SPOKE_PAUSE_ROLE, deployer);
    }
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
  function _requireLiquidationLogicLinked() internal {
    bool envExists = SpokeDeployUtils._librariesPathExists();
    require(
      envExists,
      'FOUNDRY_LIBRARIES not set. Run: forge script scripts/LibraryPreCompile.s.sol'
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
  string internal constant INPUT_FILE = 'deploy.json';
  string internal constant OUTPUT_FILE = 'AaveV4FullDeploy.json';

  constructor() AaveV4FullDeployScript(INPUT_FILE, OUTPUT_FILE) {}
}
