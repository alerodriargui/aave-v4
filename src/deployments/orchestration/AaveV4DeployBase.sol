// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';

import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4ConfiguratorBatch} from 'src/deployments/batches/AaveV4ConfiguratorBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';
import {AaveV4GatewayBatch} from 'src/deployments/batches/AaveV4GatewayBatch.sol';

library AaveV4DeployBase {
  function deployAccessBatch(
    address admin
  ) internal returns (BatchReports.AccessBatchReport memory) {
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin);
    return accessBatch.getReport();
  }

  function deployConfiguratorBatch(
    address hubConfiguratorOwner,
    address spokeConfiguratorOwner
  ) internal returns (BatchReports.ConfiguratorBatchReport memory) {
    AaveV4ConfiguratorBatch configuratorBatch = new AaveV4ConfiguratorBatch(
      hubConfiguratorOwner,
      spokeConfiguratorOwner
    );
    return configuratorBatch.getReport();
  }

  function deployHubBatch(
    address treasurySpokeOwner,
    address accessManagerAddress
  ) internal returns (BatchReports.HubBatchReport memory) {
    AaveV4HubBatch hubBatch = new AaveV4HubBatch(treasurySpokeOwner, accessManagerAddress);
    return hubBatch.getReport();
  }

  function deploySpokeInstanceBatch(
    address spokeProxyAdminOwner,
    address accessManagerAddress,
    uint8 oracleDecimals,
    string memory oracleSuffix,
    string memory label
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch({
      spokeProxyAdminOwner_: spokeProxyAdminOwner,
      accessManagerAddress_: accessManagerAddress,
      oracleDecimals_: oracleDecimals,
      oracleDescription_: string.concat(label, oracleSuffix)
    });
    return spokeInstanceBatch.getReport();
  }

  function deployGatewaysBatch(
    address owner,
    address nativeWrapper
  ) internal returns (BatchReports.GatewaysBatchReport memory) {
    AaveV4GatewayBatch gatewayBatch = new AaveV4GatewayBatch({
      owner_: owner,
      nativeWrapper_: nativeWrapper
    });
    return gatewayBatch.getReport();
  }
}
