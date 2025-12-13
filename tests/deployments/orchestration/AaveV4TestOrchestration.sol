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

import {TestTokensBatch} from 'tests/deployments/batches/TestTokensBatch.sol';

import {
  AaveV4AccessManagerRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {
  AaveV4HubRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {
  AaveV4SpokeRolesProcedure
} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';

import {
  AaveV4HubConfigProcedures
} from 'src/deployments/procedures/config/AaveV4HubConfigProcedures.sol';
import {
  AaveV4SpokeConfigProcedures
} from 'src/deployments/procedures/config/AaveV4SpokeConfigProcedures.sol';

import {AaveV4DeployBase} from 'src/deployments/orchestration/AaveV4DeployBase.sol';

import {TestTypes} from 'tests/utils/TestTypes.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';

import {Constants} from 'tests/Constants.sol';

import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

library AaveV4TestOrchestration {
  bool public constant IS_TEST = true;
  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  function deployTestTokens(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) external returns (TestTypes.TokenList memory) {
    TestTypes.TestTokensReport memory tokensReport = _deployTestTokensBatch(tokenInputs);

    TestTypes.TokenList memory tokenList;
    tokenList.weth = WETH9(payable(tokensReport.wethAddress));
    tokenList.usdx = TestnetERC20(tokensReport.testTokenAddresses[0]);
    tokenList.dai = TestnetERC20(tokensReport.testTokenAddresses[1]);
    tokenList.wbtc = TestnetERC20(tokensReport.testTokenAddresses[2]);
    tokenList.usdy = TestnetERC20(tokensReport.testTokenAddresses[3]);
    tokenList.usdz = TestnetERC20(tokensReport.testTokenAddresses[4]);
    return tokenList;
  }

  function deployTestEnv(
    address admin,
    address treasuryAdmin,
    uint256 hubCount,
    uint256 spokeCount
  ) external returns (TestTypes.TestEnvReport memory) {
    TestTypes.TestEnvReport memory report;

    report.hubReports = new TestTypes.TestHubReport[](hubCount);
    report.spokeReports = new TestTypes.TestSpokeReport[](spokeCount);

    // Deploy Access Batch
    report.accessManagerAddress = AaveV4DeployBase.deployAccessBatch(admin).accessManagerAddress;

    // Deploy Hub Batches
    for (uint256 i; i < hubCount; ++i) {
      BatchReports.HubBatchReport memory hubReport = AaveV4DeployBase.deployHubBatch(
        treasuryAdmin,
        report.accessManagerAddress
      );
      report.hubReports[i].hubAddress = hubReport.hubAddress;
      report.hubReports[i].irStrategyAddress = hubReport.irStrategyAddress;
      report.hubReports[i].treasurySpokeAddress = hubReport.treasurySpokeAddress;
    }

    // Deploy Spoke Instance Batches
    for (uint256 i; i < spokeCount; ++i) {
      BatchReports.SpokeInstanceBatchReport memory spokeReport = AaveV4DeployBase
        .deploySpokeInstanceBatch(
          admin,
          report.accessManagerAddress,
          Constants.ORACLE_DECIMALS,
          Constants.ORACLE_SUFFIX,
          string.concat('Spoke ', string(abi.encode(i)), Constants.ORACLE_SUFFIX)
        );
      report.spokeReports[i].spokeAddress = spokeReport.spokeProxyAddress;
      report.spokeReports[i].aaveOracleAddress = spokeReport.aaveOracleAddress;
    }

    return report;
  }

  function setRolesTestEnv(TestTypes.TestEnvReport memory report) public {
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
    }
  }

  function grantRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address hubAdmin,
    address spokeAdmin
  ) public {
    grantHubRolesTestEnv(report, admin, hubAdmin);
    grantSpokeRolesTestEnv(report, admin, spokeAdmin);
  }

  // function grantAccessManagerRolesTestEnv(
  //   TestTypes.TestEnvReport memory report,
  //   address admin
  // ) external {
  //   // grant RootAdmin Role
  //   AaveV4AccessManagerRolesProcedure.grantRootAdminRole({
  //     accessManagerAddress: report.accessManagerAddress,
  //     newAdminAddress: admin,
  //     currentAdminAddress: admin
  //   });
  // }

  function grantHubRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address hubAdmin
  ) public {
    // grant Hub roles
    AaveV4HubRolesProcedure.grantHubAdminRole(report.accessManagerAddress, admin);
    AaveV4HubRolesProcedure.grantHubAdminRole(report.accessManagerAddress, hubAdmin);
  }

  function grantSpokeRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address spokeAdmin
  ) public {
    // grant Spoke roles
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole(report.accessManagerAddress, admin);
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole(report.accessManagerAddress, spokeAdmin);
  }

  function configureHubsAssets(
    ConfigData.AddAssetParams[] memory paramsList
  ) public returns (uint256[] memory) {
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
  ) external returns (TestTypes.SpokeReserveId[] memory) {
    for (uint256 i; i < liquidationParamsList.length; ++i) {
      AaveV4SpokeConfigProcedures.updateLiquidationConfig(liquidationParamsList[i]);
    }
    TestTypes.SpokeReserveId[] memory spokeReserveIds = new TestTypes.SpokeReserveId[](
      reserveParamsList.length
    );
    for (uint256 i; i < reserveParamsList.length; ++i) {
      spokeReserveIds[i] = TestTypes.SpokeReserveId({
        spoke: reserveParamsList[i].spoke,
        reserveId: AaveV4SpokeConfigProcedures.addReserve(reserveParamsList[i])
      });
    }
    return spokeReserveIds;
  }

  function _deployTestTokensBatch(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) internal returns (TestTypes.TestTokensReport memory) {
    TestTypes.TestTokensReport memory report;

    report.testTokenAddresses = new address[](tokenInputs.length);

    // Deploy Test Tokens Batch
    TestTypes.TestTokensBatchReport memory tokensReport = _deployTokensBatch(tokenInputs);
    report.wethAddress = tokensReport.wethAddress;
    report.testTokenAddresses = tokensReport.tokenAddresses;

    return report;
  }

  function _deployTokensBatch(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) internal returns (TestTypes.TestTokensBatchReport memory) {
    TestTokensBatch tokensBatch = new TestTokensBatch(tokenInputs);
    return tokensBatch.getReport();
  }
}
