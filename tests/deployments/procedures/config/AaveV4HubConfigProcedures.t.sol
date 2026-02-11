// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/config/ConfigProceduresBase.t.sol';

contract AaveV4HubConfigProceduresTest is ConfigProceduresBase {
  function test_addAsset() public {
    uint256 assetId = _addDefaultAsset();

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.feeReceiver, treasurySpoke);
    assertEq(config.irStrategy, irStrategy);
  }

  function test_addAsset_withLiquidityFee() public {
    uint256 assetId = hubConfigWrapper.addAsset(
      ConfigData.AddAssetParams({
        hub: hub,
        underlying: address(underlying),
        decimals: underlying.decimals(),
        feeReceiver: treasurySpoke,
        liquidityFee: 10_00,
        irStrategy: irStrategy,
        reinvestmentController: address(0),
        irData: _defaultIrDataEncoded()
      })
    );

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.liquidityFee, 10_00);
    assertEq(config.feeReceiver, treasurySpoke);
  }

  function test_addAsset_withReinvestmentController() public {
    address controller = makeAddr('reinvestmentController');
    uint256 assetId = hubConfigWrapper.addAsset(
      ConfigData.AddAssetParams({
        hub: hub,
        underlying: address(underlying),
        decimals: underlying.decimals(),
        feeReceiver: treasurySpoke,
        liquidityFee: 0,
        irStrategy: irStrategy,
        reinvestmentController: controller,
        irData: _defaultIrDataEncoded()
      })
    );

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.reinvestmentController, controller);
  }

  function test_addAssetViaConfigurator() public {
    uint256 assetId = hubConfigWrapper.addAssetViaConfigurator(
      hubConfigurator,
      ConfigData.AddAssetParams({
        hub: hub,
        underlying: address(underlying),
        decimals: underlying.decimals(),
        feeReceiver: treasurySpoke,
        liquidityFee: 5_00,
        irStrategy: irStrategy,
        reinvestmentController: address(0),
        irData: _defaultIrDataEncoded()
      })
    );

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.feeReceiver, treasurySpoke);
    assertEq(config.liquidityFee, 5_00);
  }

  function test_updateAssetConfig() public {
    uint256 assetId = _addDefaultAsset();

    address newFeeReceiver = makeAddr('newFeeReceiver');
    hubConfigWrapper.updateAssetConfig(
      ConfigData.UpdateAssetConfigParams({
        hub: hub,
        assetId: assetId,
        config: IHub.AssetConfig({
          liquidityFee: 20_00,
          feeReceiver: newFeeReceiver,
          irStrategy: irStrategy,
          reinvestmentController: address(0)
        }),
        irData: bytes('') // must be empty when irStrategy is unchanged
      })
    );

    IHub.AssetConfig memory config = IHub(hub).getAssetConfig(assetId);
    assertEq(config.liquidityFee, 20_00);
    assertEq(config.feeReceiver, newFeeReceiver);
  }

  function test_addSpoke() public {
    uint256 assetId = _addDefaultAsset();

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: type(uint40).max,
      drawCap: type(uint40).max,
      riskPremiumThreshold: type(uint24).max
    });

    hubConfigWrapper.addSpoke(
      ConfigData.AddSpokeParams({
        hub: hub,
        assetId: assetId,
        spoke: spokeProxy,
        config: spokeConfig
      })
    );

    IHub.SpokeConfig memory stored = IHub(hub).getSpokeConfig(assetId, spokeProxy);
    assertTrue(stored.active);
    assertFalse(stored.halted);
  }

  function test_addSpokeViaConfigurator() public {
    uint256 assetId = _addDefaultAsset();

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: type(uint40).max,
      drawCap: type(uint40).max,
      riskPremiumThreshold: type(uint24).max
    });

    hubConfigWrapper.addSpokeViaConfigurator(
      hubConfigurator,
      ConfigData.AddSpokeParams({
        hub: hub,
        assetId: assetId,
        spoke: spokeProxy,
        config: spokeConfig
      })
    );

    IHub.SpokeConfig memory stored = IHub(hub).getSpokeConfig(assetId, spokeProxy);
    assertTrue(stored.active);
  }

  function test_addSpokeToAssetsViaConfigurator() public {
    uint256 assetId0 = _addDefaultAsset();

    // Deploy a second token and add it as a separate asset
    TestnetERC20 underlying2 = new TestnetERC20('Token2', 'TK2', 18);
    uint256 assetId1 = hubConfigWrapper.addAsset(
      ConfigData.AddAssetParams({
        hub: hub,
        underlying: address(underlying2),
        decimals: underlying2.decimals(),
        feeReceiver: treasurySpoke,
        liquidityFee: 0,
        irStrategy: irStrategy,
        reinvestmentController: address(0),
        irData: _defaultIrDataEncoded()
      })
    );

    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      halted: false,
      addCap: type(uint40).max,
      drawCap: type(uint40).max,
      riskPremiumThreshold: type(uint24).max
    });

    uint256[] memory assetIds = new uint256[](2);
    assetIds[0] = assetId0;
    assetIds[1] = assetId1;

    IHub.SpokeConfig[] memory configs = new IHub.SpokeConfig[](2);
    configs[0] = spokeConfig;
    configs[1] = spokeConfig;

    hubConfigWrapper.addSpokeToAssetsViaConfigurator(
      hubConfigurator,
      ConfigData.AddSpokeToAssetsParams({
        hub: hub,
        spoke: spokeProxy,
        assetIds: assetIds,
        configs: configs
      })
    );

    IHub.SpokeConfig memory stored0 = IHub(hub).getSpokeConfig(assetId0, spokeProxy);
    IHub.SpokeConfig memory stored1 = IHub(hub).getSpokeConfig(assetId1, spokeProxy);
    assertTrue(stored0.active);
    assertTrue(stored1.active);
  }

  function _addDefaultAsset() internal returns (uint256) {
    return
      hubConfigWrapper.addAsset(
        ConfigData.AddAssetParams({
          hub: hub,
          underlying: address(underlying),
          decimals: underlying.decimals(),
          feeReceiver: treasurySpoke,
          liquidityFee: 0,
          irStrategy: irStrategy,
          reinvestmentController: address(0),
          irData: _defaultIrDataEncoded()
        })
      );
  }
}
