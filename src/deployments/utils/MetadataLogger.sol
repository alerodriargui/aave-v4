// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {Logger} from 'src/deployments/utils/Logger.sol';

contract MetadataLogger is Logger {
  constructor(string memory outputPath_) Logger(outputPath_) {}

  function writeJsonReportMarket(OrchestrationReports.FullDeploymentReport memory report) public {
    _write('salt', report.salt);
    _write('accessManager', report.authorityBatchReport.accessManager);
    _write('hubConfigurator', report.configuratorBatchReport.hubConfigurator);
    _write('spokeConfigurator', report.configuratorBatchReport.spokeConfigurator);
    _write('treasurySpoke', report.treasurySpokeBatchReport.treasurySpoke);

    // Group hubs: { hub: { label: { proxy: ..., implementation: ... } }, irStrategy: { label: ... } }
    {
      uint256 hubLen = report.hubInstanceBatchReports.length;
      string[] memory hubLabels = new string[](hubLen);
      address[] memory hubProxies = new address[](hubLen);
      address[] memory hubImpls = new address[](hubLen);
      Logger.AddressEntry[] memory irEntries = new Logger.AddressEntry[](hubLen);
      for (uint256 i; i < hubLen; i++) {
        hubLabels[i] = report.hubInstanceBatchReports[i].label;
        hubProxies[i] = report.hubInstanceBatchReports[i].report.hubProxy;
        hubImpls[i] = report.hubInstanceBatchReports[i].report.hubImplementation;
        irEntries[i] = Logger.AddressEntry({
          label: report.hubInstanceBatchReports[i].label,
          value: report.hubInstanceBatchReports[i].report.irStrategy
        });
      }
      _writeNestedProxyGroup('hub', hubLabels, hubProxies, hubImpls);
      _writeGroup('irStrategy', irEntries);
    }

    // Group spokes: { spoke: { label: { proxy: ..., implementation: ... } }, oracle: { label: ... } }
    {
      uint256 spokeLen = report.spokeInstanceBatchReports.length;
      string[] memory spokeLabels = new string[](spokeLen);
      address[] memory spokeProxies = new address[](spokeLen);
      address[] memory spokeImpls = new address[](spokeLen);
      Logger.AddressEntry[] memory oracleEntries = new Logger.AddressEntry[](spokeLen);
      for (uint256 i; i < spokeLen; i++) {
        spokeLabels[i] = report.spokeInstanceBatchReports[i].label;
        spokeProxies[i] = report.spokeInstanceBatchReports[i].report.spokeProxy;
        spokeImpls[i] = report.spokeInstanceBatchReports[i].report.spokeImplementation;
        oracleEntries[i] = Logger.AddressEntry({
          label: report.spokeInstanceBatchReports[i].label,
          value: report.spokeInstanceBatchReports[i].report.aaveOracle
        });
      }
      _writeNestedProxyGroup('spoke', spokeLabels, spokeProxies, spokeImpls);
      _writeGroup('oracle', oracleEntries);
    }

    if (report.gatewaysBatchReport.signatureGateway != address(0)) {
      _write('signatureGateway', report.gatewaysBatchReport.signatureGateway);
    }
    if (report.gatewaysBatchReport.nativeGateway != address(0)) {
      _write('nativeTokenGateway', report.gatewaysBatchReport.nativeGateway);
    }
    if (report.positionManagerBatchReport.giverPositionManager != address(0)) {
      _write('giverPositionManager', report.positionManagerBatchReport.giverPositionManager);
    }
    if (report.positionManagerBatchReport.takerPositionManager != address(0)) {
      _write('takerPositionManager', report.positionManagerBatchReport.takerPositionManager);
    }
    if (report.positionManagerBatchReport.configPositionManager != address(0)) {
      _write('configPositionManager', report.positionManagerBatchReport.configPositionManager);
    }
  }
}
