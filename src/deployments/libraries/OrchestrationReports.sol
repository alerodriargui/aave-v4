// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

library OrchestrationReports {
  struct SpokeDeploymentReport {
    string label;
    BatchReports.SpokeInstanceBatchReport report;
  }

  struct HubDeploymentReport {
    string label;
    BatchReports.HubBatchReport report;
  }

  struct FullDeploymentReport {
    BatchReports.AuthorityBatchReport authorityBatchReport;
    BatchReports.ConfiguratorBatchReport configuratorBatchReport;
    BatchReports.TreasurySpokeBatchReport treasurySpokeBatchReport;
    SpokeDeploymentReport[] spokeInstanceBatchReports;
    HubDeploymentReport[] hubBatchReports;
    BatchReports.GatewaysBatchReport gatewaysBatchReport;
  }
}
