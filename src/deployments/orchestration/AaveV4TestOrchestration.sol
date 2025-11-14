// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {OrchestrationReports} from 'src/deployments/libraries/OrchestrationReports.sol';
import {ConfigData} from 'src/deployments/libraries/ConfigData.sol';

import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';
import {AaveV4HubBatch} from 'src/deployments/batches/AaveV4HubBatch.sol';
import {AaveV4SpokeInstanceBatch} from 'src/deployments/batches/AaveV4SpokeInstanceBatch.sol';

import {TestTokensBatch} from 'src/deployments/batches/TestTokensBatch.sol';

import {AaveV4AdminRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AdminRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';

import {AaveV4HubConfigProcedures} from 'src/deployments/procedures/config/AaveV4HubConfigProcedures.sol';
import {AaveV4SpokeConfigProcedures} from 'src/deployments/procedures/config/AaveV4SpokeConfigProcedures.sol';

library AaveV4TestOrchestration {
  bool public constant IS_TEST = true;
  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  uint8 private constant ORACLE_DECIMALS = 8;
  string private constant ORACLE_SUFFIX = ' (USD)';

  function deployTestEnv(
    address admin,
    address treasuryAdmin,
    uint256 hubCount,
    uint256 spokeCount
  ) external returns (OrchestrationReports.TestEnvReport memory) {
    OrchestrationReports.TestEnvReport memory report;

    report.hubReports = new OrchestrationReports.TestHubReport[](hubCount);
    report.spokeReports = new OrchestrationReports.TestSpokeReport[](spokeCount);

    // Deploy Access Batch
    report.accessManagerAddress = _deployAccessBatch(admin).accessManagerAddress;

    // Deploy Hub Batches
    for (uint256 i; i < hubCount; ++i) {
      BatchReports.HubBatchReport memory hubReport = _deployHubBatch(
        treasuryAdmin,
        report.accessManagerAddress
      );
      report.hubReports[i].hubAddress = hubReport.hubAddress;
      report.hubReports[i].irStrategyAddress = hubReport.irStrategyAddress;
      report.hubReports[i].treasurySpokeAddress = hubReport.treasurySpokeAddress;
    }

    // Deploy Spoke Instance Batches
    for (uint256 i; i < spokeCount; ++i) {
      BatchReports.SpokeInstanceBatchReport memory spokeReport = _deploySpokeInstanceBatch(
        admin,
        report.accessManagerAddress,
        string.concat('Spoke ', string(abi.encode(i)), ' (USD)')
      );
      report.spokeReports[i].spokeAddress = spokeReport.spokeProxyAddress;
      report.spokeReports[i].aaveOracleAddress = spokeReport.aaveOracleAddress;
    }

    return report;
  }

  function deployTestTokens(
    ConfigData.TestTokenInput[] memory tokenInputs
  ) external returns (OrchestrationReports.TestTokensReport memory) {
    OrchestrationReports.TestTokensReport memory report;

    report.testTokenAddresses = new address[](tokenInputs.length);

    // Deploy Test Tokens Batch
    BatchReports.TestTokensBatchReport memory tokensReport = _deployTokensBatch(tokenInputs);
    report.wethAddress = tokensReport.wethAddress;
    report.testTokenAddresses = tokensReport.tokenAddresses;

    return report;
  }

  function setRolesTestEnv(
    address admin,
    address hubAdmin,
    address spokeAdmin,
    OrchestrationReports.TestEnvReport memory report
  ) external {
    // Set Admin Roles
    AaveV4AdminRolesProcedure.setConfiguratorAdminRoles(report.accessManagerAddress, admin, admin);
    AaveV4AdminRolesProcedure.setConfiguratorHubAdminRole(report.accessManagerAddress, hubAdmin);
    AaveV4AdminRolesProcedure.setConfiguratorSpokeAdminRole(
      report.accessManagerAddress,
      spokeAdmin
    );

    // Set Hub Roles
    for (uint256 i; i < report.hubReports.length; ++i) {
      AaveV4HubRolesProcedure.setHubRoles(
        report.accessManagerAddress,
        report.hubReports[i].hubAddress
      );
    }

    // Set Spoke Roles
    for (uint256 i; i < report.spokeReports.length; ++i) {
      AaveV4SpokeRolesProcedure.setSpokeRoles(
        report.accessManagerAddress,
        report.spokeReports[i].spokeAddress
      );
      AaveV4SpokeRolesProcedure.setSpokeUserPositionAdapterRole(
        report.accessManagerAddress,
        report.spokeReports[i].spokeAddress
      );
    }
  }

  function deployTestHub(
    address admin,
    address treasuryAdmin,
    ConfigData.AddAssetParams[] memory paramsList
  ) external returns (address, OrchestrationReports.TestHubReport memory) {
    OrchestrationReports.TestHubReport memory report;

    address accessManagerAddress = _deployAccessBatch(admin).accessManagerAddress;

    // Deploy Hub Batch
    BatchReports.HubBatchReport memory hubReport = _deployHubBatch(
      treasuryAdmin,
      accessManagerAddress
    );
    report.hubAddress = hubReport.hubAddress;
    report.irStrategyAddress = hubReport.irStrategyAddress;
    report.treasurySpokeAddress = hubReport.treasurySpokeAddress;

    // Set Hub Roles
    AaveV4HubRolesProcedure.setHubRoles(accessManagerAddress, report.hubAddress);

    return (accessManagerAddress, report);
  }

  function configureHubsAssets(
    ConfigData.AddAssetParams[] memory paramsList
  ) external returns (uint256[] memory) {
    uint256[] memory assetIds = new uint256[](paramsList.length);
    for (uint256 i; i < paramsList.length; ++i) {
      assetIds[i] = AaveV4HubConfigProcedures.addAsset(paramsList[i]);
    }
    return assetIds;
  }

  function configureHubsSpokes(ConfigData.AddSpokeParams[] memory paramsList) external {
    for (uint256 i; i < paramsList.length; ++i) {
      AaveV4HubConfigProcedures.addSpoke(paramsList[i]);
    }
  }

  function configureSpokes(
    ConfigData.UpdateLiquidationConfigParams[] memory liquidationParamsList,
    ConfigData.AddReserveParams[] memory reserveParamsList
  ) external returns (uint256[] memory) {
    for (uint256 i; i < liquidationParamsList.length; ++i) {
      AaveV4SpokeConfigProcedures.updateLiquidationConfig(liquidationParamsList[i]);
    }
    uint256[] memory reserveIds = new uint256[](reserveParamsList.length);
    for (uint256 i; i < reserveParamsList.length; ++i) {
      reserveIds[i] = AaveV4SpokeConfigProcedures.addReserve(reserveParamsList[i]);
    }
    return reserveIds;
  }

  function _deployTokensBatch(
    ConfigData.TestTokenInput[] memory tokenInputs
  ) internal returns (BatchReports.TestTokensBatchReport memory) {
    TestTokensBatch tokensBatch = new TestTokensBatch(tokenInputs);
    return tokensBatch.getReport();
  }

  function _deployAccessBatch(
    address admin
  ) internal returns (BatchReports.AccessBatchReport memory) {
    AaveV4AccessBatch accessBatch = new AaveV4AccessBatch(admin);
    return accessBatch.getReport();
  }

  function _deployHubBatch(
    address admin,
    address accessManagerAddress
  ) internal returns (BatchReports.HubBatchReport memory) {
    AaveV4HubBatch hubBatch = new AaveV4HubBatch(admin, accessManagerAddress);
    return hubBatch.getReport();
  }

  function _deploySpokeInstanceBatch(
    address admin,
    address accessManagerAddress,
    string memory label
  ) internal returns (BatchReports.SpokeInstanceBatchReport memory) {
    AaveV4SpokeInstanceBatch spokeInstanceBatch = new AaveV4SpokeInstanceBatch(
      vm,
      admin,
      admin,
      accessManagerAddress,
      8,
      label
    );
    return spokeInstanceBatch.getReport();
  }
}
