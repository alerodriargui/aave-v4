// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {AaveOracle, IAaveOracle} from 'src/spoke/AaveOracle.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {ISpokeInstance} from 'tests/mocks/ISpokeInstance.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';
import {SpokeDeployUtils} from '../SpokeDeployUtils.sol';
import {ConfigReader} from '../ConfigReader.sol';
import {DeployLogger} from '../DeployLogger.sol';
import {ScriptUtils} from '../ScriptUtils.sol';
import {DeployReport, DeployReportLib} from './DeployTypes.sol';

/// @title DeployInfra
/// @notice Deploys core infrastructure: AccessManager, all spokes (oracle + SpokeInstance),
///         all hubs (Hub + TreasurySpoke + IRStrategy). Populates the DeployReport.
library DeployInfra {
  using ConfigReader for string;
  using DeployReportLib for DeployReport;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // ==================== Public Functions ====================

  /// @notice Read token keys from config, populate report.tokens[].
  ///         Deploy mock price feeds for tokens with priceFeed == address(0).
  function setUpTokens(DeployReport storage report, string memory json) internal {
    string[] memory tokenKeys = json.tokenKeys();
    for (uint256 i; i < tokenKeys.length; ++i) {
      report.pushToken(tokenKeys[i], json.tokenAddress(tokenKeys[i]), json.tokenPriceFeed(tokenKeys[i]));
    }
    _deployMockPriceFeeds(report);
  }

  /// @notice Deploy AccessManager, all spokes, and all hubs.
  ///         Populates report.admin, report.accessManager, report.spokes[], report.hubs[].
  function deployInfrastructure(DeployReport storage report, string memory json) internal {
    (, address caller, ) = vm.readCallers();
    report.admin = caller;
    report.accessManager = address(new AccessManager(caller));

    _deploySpokes(report, json, caller);
    _deployHubs(report, json);
  }

  // ==================== Private: Spokes ====================

  function _deploySpokes(DeployReport storage report, string memory json, address deployer) private {
    address liquidationLogic = SpokeDeployUtils._getLiquidationLogicAddress();
    require(liquidationLogic.code.length > 0, 'LiquidationLogic not deployed. Run LibraryPreCompile first.');

    for (uint256 si = 0; json.spokeExists(si); si++) {
      ConfigReader.SpokeDeployConfig memory sc = json.readSpoke(si);

      IAaveOracle oracle = new AaveOracle(sc.oracleDecimals, string.concat(sc.key, ' (USD)'));

      ISpoke spoke = SpokeDeployUtils.deploySpoke(
        address(oracle),
        sc.maxUserReservesLimit,
        deployer,
        abi.encodeCall(ISpokeInstance.initialize, (report.accessManager))
      );

      oracle.setSpoke(address(spoke));

      require(spoke.ORACLE() == address(oracle), 'spoke.ORACLE mismatch');
      require(oracle.SPOKE() == address(spoke), 'oracle.SPOKE mismatch');

      report.pushSpoke(sc.key, address(spoke), address(oracle));
      DeployLogger.logSpokeDeployed(sc.key, address(spoke));
    }
  }

  // ==================== Private: Hubs ====================

  function _deployHubs(DeployReport storage report, string memory json) private {
    for (uint256 hi = 0; json.hubExists(hi); hi++) {
      string memory hubKey = json.hubKey(hi);
      DeployLogger.logSection(hubKey);

      IHub hub = DeployUtils.deployHub(report.accessManager, keccak256(abi.encodePacked(hubKey)));
      address treasury = address(new TreasurySpoke(report.admin, address(hub)));
      address irStrategy = address(new AssetInterestRateStrategy(address(hub)));

      report.pushHub(hubKey, address(hub), treasury, irStrategy);
    }
  }

  // ==================== Private: Mock Feeds ====================

  /// @dev Deploy mock Chainlink feeds for tokens with priceFeed == address(0).
  ///      Currently hardcoded for wstETH and LDO. Remove when real feeds are available.
  function _deployMockPriceFeeds(DeployReport storage report) private {
    for (uint256 i; i < report.tokens.length; ++i) {
      if (report.tokens[i].priceFeed != address(0)) continue;

      if (ScriptUtils.strEq(report.tokens[i].key, 'wstETH')) {
        report.tokens[i].priceFeed = address(new MockPriceFeed(8, 'wstETH', 550429206740));
      } else if (ScriptUtils.strEq(report.tokens[i].key, 'LDO')) {
        report.tokens[i].priceFeed = address(new MockPriceFeed(8, 'LDO', 85721424));
      }
    }
  }
}
