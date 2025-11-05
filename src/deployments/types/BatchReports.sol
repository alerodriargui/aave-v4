// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BatchReports {
  struct AccessBatchReport {
    address accessManagerAddress;
  }

  struct SpokeInstanceBatchReport {
    address spokeImplementationAddress;
    address spokeProxyAddress;
    address aaveOracleAddress;
    address spokeConfiguratorAddress;
  }

  struct HubBatchReport {
    address hubAddress;
    address irStrategyAddress;
    address treasurySpokeAddress;
    address hubConfiguratorAddress;
  }

  struct GatewaysBatchReport {
    address signatureGatewayAddress;
    address nativeGatewayAddress;
  }
}
