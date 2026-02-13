// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/config-engine/AaveV4ConfigEngineBase.t.sol';

/// @title AaveV4SpokeConfigEngineTest
/// @notice Tests for AaveV4SpokeConfigEngine — reserve listing, liquidation config,
///         and all granular spoke-side update operations (reserve config, dynamic config).
///         The engine is stateless: all functions take spoke/spokeConfigurator/hub as parameters.
contract AaveV4SpokeConfigEngineTest is AaveV4ConfigEngineBaseTest {
  // ========================
  // Reserve Listing
  // ========================

  function test_spokeEngine_listReserves() public {
    _listWethAsset();
    _registerSpokeForWeth();

    IAaveV4SpokeConfigEngine.ReserveListing[]
      memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](1);
    reserves[0] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(weth),
      priceFeed: address(wethPriceFeed),
      config: ISpoke.ReserveConfig({
        collateralRisk: 50_00,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 100
      })
    });

    uint256[] memory reserveIds = spokeEngine.listReserves(
      spokeProxy,
      spokeConfigurator,
      hub,
      reserves
    );

    assertEq(reserveIds.length, 1);
  }

  function test_spokeEngine_listMultipleReserves() public {
    _listWethAsset();
    _listUsdcAsset();
    _registerSpokeForWeth();
    _registerSpokeForUsdc();

    IAaveV4SpokeConfigEngine.ReserveListing[]
      memory reserves = new IAaveV4SpokeConfigEngine.ReserveListing[](2);
    reserves[0] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(weth),
      priceFeed: address(wethPriceFeed),
      config: ISpoke.ReserveConfig({
        collateralRisk: 50_00,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 100
      })
    });
    reserves[1] = IAaveV4SpokeConfigEngine.ReserveListing({
      underlying: address(usdc),
      priceFeed: address(usdcPriceFeed),
      config: ISpoke.ReserveConfig({
        collateralRisk: 30_00,
        paused: false,
        frozen: false,
        borrowable: true,
        receiveSharesEnabled: true
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: 85_00,
        maxLiquidationBonus: 104_00,
        liquidationFee: 100
      })
    });

    uint256[] memory reserveIds = spokeEngine.listReserves(
      spokeProxy,
      spokeConfigurator,
      hub,
      reserves
    );

    assertEq(reserveIds.length, 2);
  }

  // ========================
  // Liquidation Config
  // ========================

  function test_spokeEngine_updateLiquidationConfig() public {
    _listWethAsset();
    _registerSpokeForWeth();
    _listWethReserve();

    IAaveV4SpokeConfigEngine.LiquidationConfigInput memory input = IAaveV4SpokeConfigEngine
      .LiquidationConfigInput({
        config: ISpoke.LiquidationConfig({
          targetHealthFactor: 1.1e18,
          healthFactorForMaxBonus: 0.95e18,
          liquidationBonusFactor: 100_00
        })
      });

    spokeEngine.updateLiquidationConfig(spokeProxy, spokeConfigurator, input);
  }

  // ========================
  // Granular Update: Reserve Config
  // ========================

  function test_spokeEngine_updateReserves() public {
    _listWethAsset();
    _registerSpokeForWeth();
    _listWethReserve();

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    uint256 reserveId = ISpoke(spokeProxy).getReserveId(hub, assetId);

    IAaveV4SpokeConfigEngine.ReserveConfigUpdate[]
      memory updates = new IAaveV4SpokeConfigEngine.ReserveConfigUpdate[](1);
    updates[0] = IAaveV4SpokeConfigEngine.ReserveConfigUpdate({
      reserveId: reserveId,
      config: ISpoke.ReserveConfig({
        collateralRisk: 70_00,
        paused: false,
        frozen: true,
        borrowable: false,
        receiveSharesEnabled: false
      })
    });

    spokeEngine.updateReserves(spokeProxy, spokeConfigurator, updates);

    ISpoke.ReserveConfig memory config = ISpoke(spokeProxy).getReserveConfig(reserveId);
    assertEq(config.collateralRisk, 70_00);
    assertTrue(config.frozen);
    assertFalse(config.borrowable);
    assertFalse(config.receiveSharesEnabled);
  }

  // ========================
  // Granular Update: Dynamic Config
  // ========================

  function test_spokeEngine_updateDynamicConfigs() public {
    _listWethAsset();
    _registerSpokeForWeth();
    _listWethReserve();

    uint256 assetId = IHub(hub).getAssetId(address(weth));
    uint256 reserveId = ISpoke(spokeProxy).getReserveId(hub, assetId);
    ISpoke.Reserve memory reserve = ISpoke(spokeProxy).getReserve(reserveId);

    IAaveV4SpokeConfigEngine.DynamicConfigUpdate[]
      memory updates = new IAaveV4SpokeConfigEngine.DynamicConfigUpdate[](1);
    updates[0] = IAaveV4SpokeConfigEngine.DynamicConfigUpdate({
      reserveId: reserveId,
      dynamicConfigKey: reserve.dynamicConfigKey,
      config: ISpoke.DynamicReserveConfig({
        collateralFactor: 75_00,
        maxLiquidationBonus: 108_00,
        liquidationFee: 200
      })
    });

    spokeEngine.updateDynamicConfigs(spokeProxy, spokeConfigurator, updates);

    ISpoke.DynamicReserveConfig memory dyn = ISpoke(spokeProxy).getDynamicReserveConfig(
      reserveId,
      reserve.dynamicConfigKey
    );
    assertEq(dyn.collateralFactor, 75_00);
    assertEq(dyn.maxLiquidationBonus, 108_00);
    assertEq(dyn.liquidationFee, 2_00);
  }
}
