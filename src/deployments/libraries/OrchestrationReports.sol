// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';

library OrchestrationReports {
  struct SpokeDeploymentReport {
    string label;
    BatchReports.SpokeInstanceBatchReport report;
  }

  struct HubDeploymentReport {
    string label;
    BatchReports.HubInstanceBatchReport report;
  }

  struct FullDeploymentReport {
    BatchReports.AuthorityBatchReport authorityBatchReport;
    BatchReports.ConfiguratorBatchReport configuratorBatchReport;
    BatchReports.TreasurySpokeBatchReport treasurySpokeBatchReport;
    SpokeDeploymentReport[] spokeInstanceBatchReports;
    HubDeploymentReport[] hubInstanceBatchReports;
    BatchReports.GatewaysBatchReport gatewaysBatchReport;
    BatchReports.PositionManagerBatchReport positionManagerBatchReport;
    bytes32 salt;
  }
}
