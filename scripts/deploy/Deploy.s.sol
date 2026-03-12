// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {ScriptUtils} from '../ScriptUtils.sol';
import {DeployReport} from './DeployTypes.sol';
import {DeployInfra} from './DeployInfra.sol';
import {DeployMarket} from './DeployMarket.sol';
import {DeployPeriphery} from './DeployPeriphery.sol';
import {DeployPositionManagers} from './DeployPositionManagers.sol';
import {ReportIO} from './ReportIO.sol';

contract DeployV4 is Script {
  DeployReport internal report;

  function run() external {
    string memory json = vm.readFile(vm.envOr('CONFIG_PATH', string('config/mainnet.json')));
    string memory outputPath = vm.envOr('DEPLOY_PATH', string('./output/deploy.json'));

    vm.startBroadcast();

    // Phase 1: Infrastructure — tokens, AccessManager, spokes, hubs
    DeployInfra.setUpTokens(report, json);
    DeployInfra.deployInfrastructure(report, json);

    // Phase 2: Roles — AccessManager selector→role mappings
    DeployPeriphery.setUpRoles(report, json);

    // Phase 3: Market configuration — asset listing, spoke registration, tokenization
    DeployMarket.configureMarkets(report, json);

    // Phase 4: Reserves — reserve listing + liquidation configs
    DeployPeriphery.setUpReserves(report, json);

    // Phase 5: Position managers — deploy + spoke registration
    DeployPositionManagers.deployPositionManagers(report, json);

    // Phase 6: Configurators — deploy + Level 1+2 role setup
    DeployPeriphery.deployConfigurators(report);

    // Output
    report.commit = ScriptUtils.commit();
    ReportIO.writeReport(report, outputPath);

    vm.stopBroadcast();
  }

  /// @notice Redeploy position managers on an existing deployment.
  /// Loads state from deploy.json, deploys fresh PMs, registers on all spokes, writes updated deploy.json.
  function redeployPositionManagers() external {
    string memory json = vm.readFile(vm.envOr('CONFIG_PATH', string('config/mainnet.json')));
    string memory outputPath = vm.envOr('DEPLOY_PATH', string('./output/deploy.json'));
    ReportIO.readReport(report, outputPath, json);

    vm.startBroadcast();

    // Clear old PM addresses so deployPositionManagers deploys fresh ones
    report.signatureGateway = address(0);
    report.nativeTokenGateway = address(0);
    report.giverPositionManager = address(0);
    report.takerPositionManager = address(0);
    report.configPositionManager = address(0);

    DeployPositionManagers.deployPositionManagers(report, json);

    // Update output
    report.commit = ScriptUtils.commit();
    ReportIO.writeReport(report, outputPath);

    vm.stopBroadcast();
  }

  function load() public {
    string memory json = vm.readFile(vm.envOr('CONFIG_PATH', string('config/mainnet.json')));
    string memory deployPath = vm.envOr('DEPLOY_PATH', string('./output/deploy.json'));
    ReportIO.readReport(report, deployPath, json);
  }
}
