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

import {AaveV4AccessManagerRolesProcedure} from 'src/deployments/procedures/roles/AaveV4AccessManagerRolesProcedure.sol';
import {AaveV4HubRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubRolesProcedure.sol';
import {AaveV4SpokeRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeRolesProcedure.sol';
import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {AaveV4SpokeConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4SpokeConfiguratorRolesProcedure.sol';

import {AaveV4HubConfigProcedures} from 'src/deployments/procedures/config/AaveV4HubConfigProcedures.sol';
import {AaveV4SpokeConfigProcedures} from 'src/deployments/procedures/config/AaveV4SpokeConfigProcedures.sol';

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
    tokenList.weth = WETH9(payable(tokensReport.weth));
    tokenList.usdx = TestnetERC20(tokensReport.testTokens[0]);
    tokenList.dai = TestnetERC20(tokensReport.testTokens[1]);
    tokenList.wbtc = TestnetERC20(tokensReport.testTokens[2]);
    tokenList.usdy = TestnetERC20(tokensReport.testTokens[3]);
    tokenList.usdz = TestnetERC20(tokensReport.testTokens[4]);
    return tokenList;
  }

  function deployTestEnv(
    address admin,
    address treasuryAdmin,
    uint256 hubCount,
    uint256 spokeCount,
    address nativeWrapper,
    bytes memory hubBytecode,
    bytes memory spokeBytecode,
    bytes32 salt
  ) external returns (TestTypes.TestEnvReport memory) {
    TestTypes.TestEnvReport memory report;

    report.hubReports = new TestTypes.TestHubReport[](hubCount);
    report.spokeReports = new TestTypes.TestSpokeReport[](spokeCount);

    // Deploy Access Batch
    report.accessManager = AaveV4DeployBase.deployAccessBatch(admin, salt).accessManager;

    // Deploy Hub Batches
    for (uint256 i; i < hubCount; ++i) {
      BatchReports.HubBatchReport memory hubReport = AaveV4DeployBase.deployHubBatch({
        treasurySpokeOwner: treasuryAdmin,
        authority: report.accessManager,
        hubBytecode: hubBytecode,
        salt: keccak256(abi.encodePacked(salt, 'hub-', string(abi.encode(i))))
      });
      report.hubReports[i].hub = hubReport.hub;
      report.hubReports[i].irStrategy = hubReport.irStrategy;
      report.hubReports[i].treasurySpoke = hubReport.treasurySpoke;
    }

    // Deploy Spoke Instance Batches
    for (uint256 i; i < spokeCount; ++i) {
      BatchReports.SpokeInstanceBatchReport memory spokeReport = AaveV4DeployBase
        .deploySpokeInstanceBatch({
          spokeProxyAdminOwner: admin,
          authority: report.accessManager,
          spokeBytecode: spokeBytecode,
          oracleDecimals: Constants.ORACLE_DECIMALS,
          oracleDescription: string.concat(
            'Spoke ',
            string(abi.encode(i)),
            Constants.ORACLE_SUFFIX
          ),
          maxUserReservesLimit: Constants.MAX_ALLOWED_USER_RESERVES_LIMIT,
          salt: keccak256(abi.encodePacked(salt, 'spoke-', string(abi.encode(i))))
        });
      report.spokeReports[i].spoke = spokeReport.spokeProxy;
      report.spokeReports[i].aaveOracle = spokeReport.aaveOracle;
    }

    // Deploy Configurator Batches with AccessManager as authority
    BatchReports.ConfiguratorBatchReport memory configuratorReport = AaveV4DeployBase
      .deployConfiguratorBatch({
        hubConfiguratorAuthority: report.accessManager,
        spokeConfiguratorAuthority: report.accessManager,
        salt: keccak256(abi.encodePacked(salt, 'configurator'))
      });
    report.configuratorReport.hubConfigurator = configuratorReport.hubConfigurator;
    report.configuratorReport.spokeConfigurator = configuratorReport.spokeConfigurator;

    // Deploy Gateways Batch
    BatchReports.GatewaysBatchReport memory gatewaysReport = AaveV4DeployBase.deployGatewaysBatch({
      owner: admin,
      nativeWrapper: nativeWrapper,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      salt: keccak256(abi.encodePacked(salt, 'gateways'))
    });
    report.gatewaysReport.signatureGateway = gatewaysReport.signatureGateway;
    report.gatewaysReport.nativeGateway = gatewaysReport.nativeGateway;

    return report;
  }

  function deployTestHub(
    address accessManager,
    address treasuryAdmin,
    bytes memory hubBytecode,
    string memory label,
    bytes32 salt
  ) external returns (TestTypes.TestHubReport memory) {
    TestTypes.TestHubReport memory report;
    BatchReports.HubBatchReport memory hubReport = AaveV4DeployBase.deployHubBatch({
      treasurySpokeOwner: treasuryAdmin,
      authority: accessManager,
      hubBytecode: hubBytecode,
      salt: keccak256(abi.encodePacked(salt, 'hub-', label))
    });
    report.hub = hubReport.hub;
    report.irStrategy = hubReport.irStrategy;
    report.treasurySpoke = hubReport.treasurySpoke;

    return report;
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

  function setRolesTestEnv(TestTypes.TestEnvReport memory report) public {
    // Set Hub Roles
    for (uint256 i; i < report.hubReports.length; ++i) {
      AaveV4HubRolesProcedure.setupHubRoles(report.accessManager, report.hubReports[i].hub);
    }

    // Set Spoke Roles
    for (uint256 i; i < report.spokeReports.length; ++i) {
      AaveV4SpokeRolesProcedure.setupSpokeRoles(report.accessManager, report.spokeReports[i].spoke);
    }

    // Set Configurator Roles
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRoles(
      report.accessManager,
      report.configuratorReport.hubConfigurator
    );
    AaveV4SpokeConfiguratorRolesProcedure.setupSpokeConfiguratorRoles(
      report.accessManager,
      report.configuratorReport.spokeConfigurator
    );
  }

  function setHubRolesTestEnv(TestTypes.TestHubReport memory report, address accessManager) public {
    AaveV4HubRolesProcedure.setupHubRoles(accessManager, report.hub);
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

  function grantHubRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address hubAdmin
  ) public {
    // grant Hub Admin roles
    AaveV4HubRolesProcedure.grantHubAdminRole(report.accessManager, admin);
    AaveV4HubRolesProcedure.grantHubAdminRole(report.accessManager, hubAdmin);

    // grant Hub Configurator role
    AaveV4HubRolesProcedure.grantHubConfiguratorRole(
      report.accessManager,
      report.configuratorReport.hubConfigurator
    );

    // grant HubConfigurator Admin roles (allows admin to call HubConfigurator functions)
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(report.accessManager, admin);
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(
      report.accessManager,
      hubAdmin
    );
  }

  function grantSpokeRolesTestEnv(
    TestTypes.TestEnvReport memory report,
    address admin,
    address spokeAdmin
  ) public {
    // grant Spoke roles
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole(report.accessManager, admin);
    AaveV4SpokeRolesProcedure.grantSpokeAdminRole(report.accessManager, spokeAdmin);

    // grant Spoke Configurator roles (allows SpokeConfigurator to call Spoke functions)
    AaveV4SpokeRolesProcedure.grantSpokeConfiguratorRole(
      report.accessManager,
      report.configuratorReport.spokeConfigurator
    );

    // grant SpokeConfigurator Admin roles (allows admin to call SpokeConfigurator functions)
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      report.accessManager,
      admin
    );
    AaveV4SpokeConfiguratorRolesProcedure.grantSpokeConfiguratorAllRoles(
      report.accessManager,
      spokeAdmin
    );
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

  function configureHubsAssetsViaConfigurator(
    ConfigData.AddAssetParams[] memory paramsList,
    address hubConfigurator
  ) public returns (uint256[] memory) {
    uint256[] memory assetIds = new uint256[](paramsList.length);
    for (uint256 i; i < paramsList.length; ++i) {
      assetIds[i] = AaveV4HubConfigProcedures.addAssetViaConfigurator(
        hubConfigurator,
        paramsList[i]
      );
    }
    return assetIds;
  }

  function _deployTestTokensBatch(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) internal returns (TestTypes.TestTokensReport memory) {
    TestTypes.TestTokensReport memory report;

    report.testTokens = new address[](tokenInputs.length);

    // Deploy Test Tokens Batch
    TestTypes.TestTokensBatchReport memory tokensReport = _deployTokensBatch(tokenInputs);
    report.weth = tokensReport.weth;
    report.testTokens = tokensReport.tokens;

    return report;
  }

  function _deployTokensBatch(
    TestTypes.TestTokenInput[] memory tokenInputs
  ) internal returns (TestTypes.TestTokensBatchReport memory) {
    TestTokensBatch tokensBatch = new TestTokensBatch(tokenInputs);
    return tokensBatch.getReport();
  }
}
