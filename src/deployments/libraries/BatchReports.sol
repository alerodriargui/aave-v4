// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library BatchReports {
  struct AuthorityBatchReport {
    address accessManager;
  }

  struct ConfiguratorBatchReport {
    address hubConfigurator;
    address spokeConfigurator;
  }

  struct SpokeInstanceBatchReport {
    address spokeImplementation;
    address spokeProxy;
    address aaveOracle;
  }

  struct HubBatchReport {
    address hub;
    address irStrategy;
  }

  struct TreasurySpokeBatchReport {
    address treasurySpoke;
  }

  struct GatewaysBatchReport {
    address signatureGateway;
    address nativeGateway;
  }

  struct PositionManagerBatchReport {
    address giverPositionManager;
    address takerPositionManager;
  }

  struct TokenizationSpokeBatchReport {
    address tokenizationSpokeImplementation;
    address tokenizationSpokeProxy;
  }
}
