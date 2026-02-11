// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/config/ConfigProceduresBase.t.sol';

contract AaveV4SpokeConfigProceduresTest is ConfigProceduresBase {
  uint256 public assetId;

  function setUp() public override {
    super.setUp();

    // Add an asset and register the spoke for it on the hub, so spoke.addReserve works
    // We need the hub config wrapper for this setup
    assetId = hubConfigWrapper.addAsset(
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
  }

  function test_updateLiquidationConfig() public {
    ISpoke.LiquidationConfig memory config = ISpoke.LiquidationConfig({
      targetHealthFactor: 1.05e18,
      healthFactorForMaxBonus: 0.7e18,
      liquidationBonusFactor: 20_00
    });

    spokeConfigWrapper.updateLiquidationConfig(
      ConfigData.UpdateLiquidationConfigParams({spoke: spokeProxy, config: config})
    );

    ISpoke.LiquidationConfig memory stored = ISpoke(spokeProxy).getLiquidationConfig();
    assertEq(stored.targetHealthFactor, 1.05e18);
    assertEq(stored.healthFactorForMaxBonus, 0.7e18);
    assertEq(stored.liquidationBonusFactor, 20_00);
  }
  function test_updateLiquidationConfigViaConfigurator() public {
    ISpoke.LiquidationConfig memory config = ISpoke.LiquidationConfig({
      targetHealthFactor: 1.04e18,
      healthFactorForMaxBonus: 0.8e18,
      liquidationBonusFactor: 15_00
    });

    spokeConfigWrapper.updateLiquidationConfigViaConfigurator(
      spokeConfigurator,
      ConfigData.UpdateLiquidationConfigParams({spoke: spokeProxy, config: config})
    );

    ISpoke.LiquidationConfig memory stored = ISpoke(spokeProxy).getLiquidationConfig();
    assertEq(stored.targetHealthFactor, 1.04e18);
    assertEq(stored.healthFactorForMaxBonus, 0.8e18);
    assertEq(stored.liquidationBonusFactor, 15_00);
  }

  function test_addReserve() public {
    spokeConfigWrapper.updateLiquidationConfig(
      ConfigData.UpdateLiquidationConfigParams({
        spoke: spokeProxy,
        config: ISpoke.LiquidationConfig({
          targetHealthFactor: 1.05e18,
          healthFactorForMaxBonus: 0.7e18,
          liquidationBonusFactor: 20_00
        })
      })
    );

    address priceFeed = _deployMockPriceFeed(2000e8);

    uint256 reserveId = spokeConfigWrapper.addReserve(
      ConfigData.AddReserveParams({
        spoke: spokeProxy,
        hub: hub,
        assetId: assetId,
        priceSource: priceFeed,
        config: ISpoke.ReserveConfig({
          collateralRisk: 15_00,
          paused: false,
          frozen: false,
          borrowable: true,
          receiveSharesEnabled: true
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 80_00,
          maxLiquidationBonus: 105_00,
          liquidationFee: 10_00
        })
      })
    );

    ISpoke.ReserveConfig memory storedConfig = ISpoke(spokeProxy).getReserveConfig(reserveId);
    assertEq(storedConfig.collateralRisk, 15_00);
    assertTrue(storedConfig.borrowable);
    assertFalse(storedConfig.paused);
    assertFalse(storedConfig.frozen);
  }

  function test_addReserveViaConfigurator() public {
    spokeConfigWrapper.updateLiquidationConfig(
      ConfigData.UpdateLiquidationConfigParams({
        spoke: spokeProxy,
        config: ISpoke.LiquidationConfig({
          targetHealthFactor: 1.05e18,
          healthFactorForMaxBonus: 0.7e18,
          liquidationBonusFactor: 20_00
        })
      })
    );

    address priceFeed = _deployMockPriceFeed(1e8);

    uint256 reserveId = spokeConfigWrapper.addReserveViaConfigurator(
      spokeConfigurator,
      ConfigData.AddReserveParams({
        spoke: spokeProxy,
        hub: hub,
        assetId: assetId,
        priceSource: priceFeed,
        config: ISpoke.ReserveConfig({
          collateralRisk: 20_00,
          paused: false,
          frozen: false,
          borrowable: true,
          receiveSharesEnabled: true
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 75_00,
          maxLiquidationBonus: 103_00,
          liquidationFee: 15_00
        })
      })
    );

    ISpoke.ReserveConfig memory storedConfig = ISpoke(spokeProxy).getReserveConfig(reserveId);
    assertEq(storedConfig.collateralRisk, 20_00);
    assertTrue(storedConfig.borrowable);
  }
}
