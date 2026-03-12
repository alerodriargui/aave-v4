// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

contract MetadataLogger is Logger {
  constructor(string memory outputPath_) Logger(outputPath_) {}

  function writeJsonReportMarket(OrchestrationReports.FullDeploymentReport memory report) public {
    _write('Salt', report.salt);
    _write('AccessManager', report.authorityBatchReport.accessManager);
    _write('HubConfigurator', report.configuratorBatchReport.hubConfigurator);
    _write('SpokeConfigurator', report.configuratorBatchReport.spokeConfigurator);
    _write('TreasurySpoke', report.treasurySpokeBatchReport.treasurySpoke);

    for (uint256 i; i < report.hubBatchReports.length; i++) {
      Logger.AddressEntry[] memory hubEntries = new Logger.AddressEntry[](2);
      hubEntries[0] = Logger.AddressEntry({
        label: 'Hub',
        value: report.hubBatchReports[i].report.hub
      });
      hubEntries[1] = Logger.AddressEntry({
        label: 'InterestRateStrategy',
        value: report.hubBatchReports[i].report.irStrategy
      });
      _writeGroup(report.hubBatchReports[i].label, hubEntries);
    }

    for (uint256 i; i < report.spokeInstanceBatchReports.length; i++) {
      Logger.AddressEntry[] memory spokeInstanceEntries = new Logger.AddressEntry[](3);
      spokeInstanceEntries[0] = Logger.AddressEntry({
        label: 'SpokeInstance Proxy',
        value: report.spokeInstanceBatchReports[i].report.spokeProxy
      });
      spokeInstanceEntries[1] = Logger.AddressEntry({
        label: 'SpokeInstance Implementation',
        value: report.spokeInstanceBatchReports[i].report.spokeImplementation
      });
      spokeInstanceEntries[2] = Logger.AddressEntry({
        label: 'AaveOracle',
        value: report.spokeInstanceBatchReports[i].report.aaveOracle
      });
      _writeGroup(report.spokeInstanceBatchReports[i].label, spokeInstanceEntries);
    }

    if (report.gatewaysBatchReport.signatureGateway != address(0)) {
      _write('SignatureGateway', report.gatewaysBatchReport.signatureGateway);
    }
    if (report.gatewaysBatchReport.nativeGateway != address(0)) {
      _write('NativeTokenGateway', report.gatewaysBatchReport.nativeGateway);
    }
    if (report.positionManagerBatchReport.giverPositionManager != address(0)) {
      _write('GiverPositionManager', report.positionManagerBatchReport.giverPositionManager);
    }
    if (report.positionManagerBatchReport.takerPositionManager != address(0)) {
      _write('TakerPositionManager', report.positionManagerBatchReport.takerPositionManager);
    }
  }
}
