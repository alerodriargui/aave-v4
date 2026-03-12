// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';
import {ConfigReader} from '../ConfigReader.sol';
import {DeployLogger} from '../DeployLogger.sol';
import {ScriptUtils} from '../ScriptUtils.sol';
import {DeployReport, DeployReportLib, HubReport} from './DeployTypes.sol';

/// @title DeployMarket
/// @notice Lists assets on hubs, registers spokes on hub-asset pairs,
///         and deploys tokenization spokes. Populates report.tokenized[].
library DeployMarket {
  using ConfigReader for string;
  using DeployReportLib for DeployReport;

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // ==================== Public Functions ====================

  /// @notice List assets, register spokes, deploy tokenization spokes.
  function configureMarkets(DeployReport storage report, string memory json) internal {
    _listAssets(report, json);
    _registerSpokes(report, json);
    _deployTokenizationSpokes(report, json);
  }

  // ==================== Private: Asset Listing ====================

  function _listAssets(DeployReport storage report, string memory json) private {
    DeployLogger.logSection('Asset Listing');
    for (uint256 ai = 0; json.assetExists(ai); ai++) {
      _processAsset(report, json.readAsset(ai));
    }
  }

  function _processAsset(
    DeployReport storage report,
    ConfigReader.AssetConfig memory conf
  ) private {
    HubReport storage hubRpt = report.findHub(conf.hubKey);
    IHub hub = IHub(hubRpt.hub);
    address token = report.findToken(conf.tokenKey).token;

    uint256 aid = hub.addAsset(
      token,
      IERC20Metadata(token).decimals(),
      hubRpt.treasury,
      hubRpt.irStrategy,
      abi.encode(conf.irData)
    );

    require(
      keccak256(
        abi.encode(IAssetInterestRateStrategy(hubRpt.irStrategy).getInterestRateData(aid))
      ) == keccak256(abi.encode(conf.irData)),
      'IR data mismatch'
    );

    {
      IHub.AssetConfig memory assetConfig = hub.getAssetConfig(aid);
      assetConfig.liquidityFee = conf.liquidityFee;
      hub.updateAssetConfig(aid, assetConfig, new bytes(0));
      assetConfig = hub.getAssetConfig(aid);
      require(assetConfig.liquidityFee == conf.liquidityFee, 'liquidityFee mismatch');
      require(assetConfig.feeReceiver == hubRpt.treasury, 'feeReceiver mismatch');
      require(assetConfig.irStrategy == hubRpt.irStrategy, 'irStrategy mismatch');
    }

    DeployLogger.logAssetListed(conf, aid, hubRpt.treasury, hubRpt.irStrategy);
  }

  // ==================== Private: Spoke Registration ====================

  function _registerSpokes(DeployReport storage report, string memory json) private {
    DeployLogger.logSection('Spoke Registration');
    for (uint256 si = 0; json.spokeRegExists(si); si++) {
      _processSpokeReg(report, json.readSpokeReg(si));
    }
  }

  function _processSpokeReg(
    DeployReport storage report,
    ConfigReader.SpokeRegConfig memory conf
  ) private {
    IHub hub = report.hubAddress(conf.hubKey);
    address spokeAddr = report.findSpoke(conf.spokeKey).spoke;
    address token = report.findToken(conf.assetKey).token;
    uint256 aid = ScriptUtils.assetId(hub, token);

    IHub.SpokeConfig memory sc = IHub.SpokeConfig({
      addCap: conf.addCap,
      drawCap: conf.drawCap,
      riskPremiumThreshold: conf.riskPremiumThreshold,
      active: conf.active,
      halted: conf.halted
    });
    hub.addSpoke(aid, spokeAddr, sc);

    IHub.SpokeConfig memory actual = hub.getSpokeConfig(aid, spokeAddr);
    require(actual.addCap == conf.addCap, 'addCap mismatch');
    require(actual.drawCap == conf.drawCap, 'drawCap mismatch');
    require(actual.active, 'spoke not active');

    DeployLogger.logSpokeRegistered(conf, actual);
  }

  // ==================== Private: Tokenization Spokes ====================

  function _deployTokenizationSpokes(DeployReport storage report, string memory json) private {
    (, address deployer, ) = vm.readCallers();
    DeployLogger.logSection('Tokenization Spoke Deployment');

    for (uint256 ai = 0; json.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = json.readAsset(ai);
      if (!asset.tokenizeEnabled) continue;
      _deployOneTokenizationSpoke(report, asset, deployer);
    }
  }

  function _deployOneTokenizationSpoke(
    DeployReport storage report,
    ConfigReader.AssetConfig memory asset,
    address deployer
  ) private {
    HubReport storage hubRpt = report.findHub(asset.hubKey);
    IHub hub = IHub(hubRpt.hub);
    address token = report.findToken(asset.tokenKey).token;
    uint256 aid = ScriptUtils.assetId(hub, token);

    string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4);
    string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);

    address ts;
    {
      address impl = address(new TokenizationSpokeInstance(hubRpt.hub, token));
      string memory shareName = string.concat(hubPrefix, ' ', asset.tokenKey);
      string memory shareSymbol = string.concat('t', asset.tokenKey, '-', hubPrefix);
      ts = DeployUtils.proxify(
        impl,
        deployer,
        abi.encodeCall(TokenizationSpokeInstance.initialize, (shareName, shareSymbol))
      );
    }

    hub.addSpoke(
      aid,
      ts,
      IHub.SpokeConfig({
        addCap: asset.tokenizeAddCap,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    );

    report.pushTokenized(tsKey, ts);
    DeployLogger.logTokenizationSpokeDeployed(tsKey, ts);
  }
}
