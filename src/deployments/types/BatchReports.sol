// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library BatchReports {
  struct AccessBatchReport {
    address accessManagerAddress;
  }

  struct ConfiguratorBatchReport {
    address hubConfiguratorAddress;
    address spokeConfiguratorAddress;
  }

  struct SpokeInstanceBatchReport {
    address spokeImplementationAddress;
    address spokeProxyAddress;
    address aaveOracleAddress;
  }

  struct HubBatchReport {
    address hubAddress;
    address irStrategyAddress;
    address treasurySpokeAddress;
  }

  struct GatewaysBatchReport {
    address signatureGatewayAddress;
    address nativeGatewayAddress;
  }
}
