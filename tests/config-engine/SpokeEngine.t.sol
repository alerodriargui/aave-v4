// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {EngineFlags} from 'src/config-engine/EngineFlags.sol';

import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';

contract SpokeEngineTest is BaseConfigEngineTest {
  function test_executeSpokeReserveConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, 5000);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePausedCalled(SPOKE, RESERVE_ID, false);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateFrozenCalled(SPOKE, RESERVE_ID, false);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateBorrowableCalled(SPOKE, RESERVE_ID, true);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReceiveSharesEnabledCalled(SPOKE, RESERVE_ID, true);

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function test_executeSpokeReserveConfigUpdates_allKeepCurrent() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        collateralRisk: EngineFlags.KEEP_CURRENT,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeSpokeReserveConfigUpdates_onlyCollateralRisk() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        collateralRisk: 7500,
        paused: EngineFlags.KEEP_CURRENT,
        frozen: EngineFlags.KEEP_CURRENT,
        borrowable: EngineFlags.KEEP_CURRENT,
        receiveSharesEnabled: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, 7500);

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function testFuzz_executeSpokeReserveConfigUpdates(
    uint256 collateralRisk,
    bool paused_,
    bool frozen_,
    bool borrowable_,
    bool receiveSharesEnabled_
  ) public {
    vm.assume(collateralRisk != EngineFlags.KEEP_CURRENT);
    uint256 paused = EngineFlags.fromBool(paused_);
    uint256 frozen = EngineFlags.fromBool(frozen_);
    uint256 borrowable = EngineFlags.fromBool(borrowable_);
    uint256 receiveSharesEnabled = EngineFlags.fromBool(receiveSharesEnabled_);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .ReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        collateralRisk: collateralRisk,
        paused: paused,
        frozen: frozen,
        borrowable: borrowable,
        receiveSharesEnabled: receiveSharesEnabled
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, collateralRisk);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePausedCalled(SPOKE, RESERVE_ID, paused_);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateFrozenCalled(SPOKE, RESERVE_ID, frozen_);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateBorrowableCalled(SPOKE, RESERVE_ID, borrowable_);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReceiveSharesEnabledCalled(
      SPOKE,
      RESERVE_ID,
      receiveSharesEnabled_
    );

    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function test_executeSpokeReserveConfigUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateCollateralRisk.selector, true);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateCollateralRiskReverted.selector);
    engine.executeSpokeReserveConfigUpdates(_toReserveConfigUpdateArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(1.05e18),
      uint64(0.95e18),
      uint16(10000)
    );

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_targetOnly() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationTargetHealthFactorCalled(SPOKE, 1.05e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeLiquidationConfigUpdates_maxBonusOnly() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateHealthFactorForMaxBonusCalled(SPOKE, 0.95e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeLiquidationConfigUpdates_bonusFactorOnly() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: 10000
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationBonusFactorCalled(SPOKE, 10000);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 1);
  }

  function test_executeSpokeLiquidationConfigUpdates_twoOfThree() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: 1.05e18,
        healthFactorForMaxBonus: 0.95e18,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationTargetHealthFactorCalled(SPOKE, 1.05e18);

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateHealthFactorForMaxBonusCalled(SPOKE, 0.95e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 2);
  }

  function test_executeSpokeLiquidationConfigUpdates_noneSet() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: EngineFlags.KEEP_CURRENT,
        healthFactorForMaxBonus: EngineFlags.KEEP_CURRENT,
        liquidationBonusFactor: EngineFlags.KEEP_CURRENT
      });

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executeSpokeLiquidationConfigUpdates(
    uint256 targetHealthFactor,
    uint256 healthFactorForMaxBonus,
    uint256 liquidationBonusFactor
  ) public {
    targetHealthFactor = bound(targetHealthFactor, 0, type(uint128).max);
    healthFactorForMaxBonus = bound(healthFactorForMaxBonus, 0, type(uint64).max);
    liquidationBonusFactor = bound(liquidationBonusFactor, 0, type(uint16).max);

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = IAaveV4ConfigEngine
      .LiquidationConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        targetHealthFactor: targetHealthFactor,
        healthFactorForMaxBonus: healthFactorForMaxBonus,
        liquidationBonusFactor: liquidationBonusFactor
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(targetHealthFactor),
      uint64(healthFactorForMaxBonus),
      uint16(liquidationBonusFactor)
    );

    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateLiquidationConfig.selector,
      true
    );

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateLiquidationConfigReverted.selector);
    engine.executeSpokeLiquidationConfigUpdates(_toLiquidationConfigUpdateArray(update));
  }

  function _setupDynamicReserveConfig(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) internal {
    mockSpokeReader.setDynamicReserveConfig(
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      ISpoke.DynamicReserveConfig({
        collateralFactor: collateralFactor,
        maxLiquidationBonus: maxLiquidationBonus,
        liquidationFee: liquidationFee
      })
    );
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allUpdated() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      8000,
      10500,
      1000
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_allKeepCurrent() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        reserveId: RESERVE_ID,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: EngineFlags.KEEP_CURRENT,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: EngineFlags.KEEP_CURRENT
      });

    // When all fields are KEEP_CURRENT the external write call should be skipped entirely.
    vm.recordLogs();
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeSpokeDynamicReserveConfigUpdates_partialUpdate() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate memory update = IAaveV4ConfigEngine
      .DynamicReserveConfigUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: address(mockSpokeReader),
        reserveId: RESERVE_ID,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 9000,
        maxLiquidationBonus: EngineFlags.KEEP_CURRENT,
        liquidationFee: 500
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      9000,
      10000,
      500
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertReader() public {
    mockSpokeReader.setShouldRevertOnRead(true);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectRevert('MOCK_READ_REVERT');
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertConfigurator() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateDynamicReserveConfig.selector,
      true
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateDynamicReserveConfigReverted.selector);
    engine.executeSpokeDynamicReserveConfigUpdates(_toDynamicReserveConfigUpdateArray(update));
  }

  function test_executeSpokeReserveListings_concrete() public {
    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddReserveCalled(
      SPOKE,
      HUB,
      ASSET_ID,
      PRICE_SOURCE,
      5000,
      false,
      false,
      true,
      true,
      8000,
      10500,
      200
    );

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function testFuzz_executeSpokeReserveListings(
    uint24 collateralRisk,
    bool paused,
    bool frozen,
    bool borrowable,
    bool receiveSharesEnabled,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    IAaveV4ConfigEngine.ReserveListing memory listing = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      hub: HUB,
      assetId: ASSET_ID,
      priceSource: PRICE_SOURCE,
      config: ISpoke.ReserveConfig({
        collateralRisk: collateralRisk,
        paused: paused,
        frozen: frozen,
        borrowable: borrowable,
        receiveSharesEnabled: receiveSharesEnabled
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: collateralFactor,
        maxLiquidationBonus: maxLiquidationBonus,
        liquidationFee: liquidationFee
      })
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddReserveCalled(
      SPOKE,
      HUB,
      ASSET_ID,
      PRICE_SOURCE,
      collateralRisk,
      paused,
      frozen,
      borrowable,
      receiveSharesEnabled,
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );

    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function test_executeSpokeReserveListings_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addReserve.selector, true);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();

    vm.expectRevert(MockSpokeConfigurator.AddReserveReverted.selector);
    engine.executeSpokeReserveListings(_toReserveListingArray(listing));
  }

  function test_executeSpokeReservePriceSourceUpdates_concrete() public {
    IAaveV4ConfigEngine.ReservePriceSourceUpdate memory update = _defaultReservePriceSourceUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(SPOKE, RESERVE_ID, PRICE_SOURCE);

    engine.executeSpokeReservePriceSourceUpdates(_toReservePriceSourceUpdateArray(update));
  }

  function testFuzz_executeSpokeReservePriceSourceUpdates(
    uint256 reserveId,
    address priceSource
  ) public {
    IAaveV4ConfigEngine.ReservePriceSourceUpdate memory update = IAaveV4ConfigEngine
      .ReservePriceSourceUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: reserveId,
        priceSource: priceSource
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateReservePriceSourceCalled(SPOKE, reserveId, priceSource);

    engine.executeSpokeReservePriceSourceUpdates(_toReservePriceSourceUpdateArray(update));
  }

  function test_executeSpokeReservePriceSourceUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateReservePriceSource.selector,
      true
    );

    IAaveV4ConfigEngine.ReservePriceSourceUpdate memory update = _defaultReservePriceSourceUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateReservePriceSourceReverted.selector);
    engine.executeSpokeReservePriceSourceUpdates(_toReservePriceSourceUpdateArray(update));
  }

  function test_executeSpokeDynamicReserveConfigAdditions_concrete() public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddDynamicReserveConfigCalled(SPOKE, RESERVE_ID, 8000, 10500, 200);

    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function testFuzz_executeSpokeDynamicReserveConfigAdditions(
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  ) public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition memory addition = IAaveV4ConfigEngine
      .DynamicReserveConfigAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: collateralFactor,
          maxLiquidationBonus: maxLiquidationBonus,
          liquidationFee: liquidationFee
        })
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddDynamicReserveConfigCalled(
      SPOKE,
      RESERVE_ID,
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );

    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function test_executeSpokeDynamicReserveConfigAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.addDynamicReserveConfig.selector,
      true
    );

    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    vm.expectRevert(MockSpokeConfigurator.AddDynamicReserveConfigReverted.selector);
    engine.executeSpokeDynamicReserveConfigAdditions(
      _toDynamicReserveConfigAdditionArray(addition)
    );
  }

  function test_executeSpokeCollateralFactorAdditions_concrete() public {
    IAaveV4ConfigEngine.CollateralFactorAddition
      memory addition = _defaultCollateralFactorAddition();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddCollateralFactorCalled(SPOKE, RESERVE_ID, 8000);

    engine.executeSpokeCollateralFactorAdditions(_toCollateralFactorAdditionArray(addition));
  }

  function testFuzz_executeSpokeCollateralFactorAdditions(uint256 collateralFactor) public {
    collateralFactor = bound(collateralFactor, 0, type(uint16).max);

    IAaveV4ConfigEngine.CollateralFactorAddition memory addition = IAaveV4ConfigEngine
      .CollateralFactorAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        collateralFactor: collateralFactor
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddCollateralFactorCalled(
      SPOKE,
      RESERVE_ID,
      uint16(collateralFactor)
    );

    engine.executeSpokeCollateralFactorAdditions(_toCollateralFactorAdditionArray(addition));
  }

  function test_executeSpokeCollateralFactorAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addCollateralFactor.selector, true);

    IAaveV4ConfigEngine.CollateralFactorAddition
      memory addition = _defaultCollateralFactorAddition();

    vm.expectRevert(MockSpokeConfigurator.AddCollateralFactorReverted.selector);
    engine.executeSpokeCollateralFactorAdditions(_toCollateralFactorAdditionArray(addition));
  }

  function test_executeSpokeCollateralFactorUpdates_concrete() public {
    IAaveV4ConfigEngine.CollateralFactorUpdate memory update = _defaultCollateralFactorUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralFactorCalled(
      SPOKE,
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      9000
    );

    engine.executeSpokeCollateralFactorUpdates(_toCollateralFactorUpdateArray(update));
  }

  function testFuzz_executeSpokeCollateralFactorUpdates(
    uint256 dynamicConfigKey,
    uint256 collateralFactor
  ) public {
    dynamicConfigKey = bound(dynamicConfigKey, 0, type(uint32).max);
    collateralFactor = bound(collateralFactor, 0, type(uint16).max);

    IAaveV4ConfigEngine.CollateralFactorUpdate memory update = IAaveV4ConfigEngine
      .CollateralFactorUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfigKey: dynamicConfigKey,
        collateralFactor: collateralFactor
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateCollateralFactorCalled(
      SPOKE,
      RESERVE_ID,
      uint32(dynamicConfigKey),
      uint16(collateralFactor)
    );

    engine.executeSpokeCollateralFactorUpdates(_toCollateralFactorUpdateArray(update));
  }

  function test_executeSpokeCollateralFactorUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateCollateralFactor.selector, true);

    IAaveV4ConfigEngine.CollateralFactorUpdate memory update = _defaultCollateralFactorUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateCollateralFactorReverted.selector);
    engine.executeSpokeCollateralFactorUpdates(_toCollateralFactorUpdateArray(update));
  }

  function test_executeSpokeMaxLiquidationBonusAdditions_concrete() public {
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition
      memory addition = _defaultMaxLiquidationBonusAddition();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddMaxLiquidationBonusCalled(SPOKE, RESERVE_ID, 10500);

    engine.executeSpokeMaxLiquidationBonusAdditions(_toMaxLiquidationBonusAdditionArray(addition));
  }

  function testFuzz_executeSpokeMaxLiquidationBonusAdditions(uint256 maxLiquidationBonus) public {
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition memory addition = IAaveV4ConfigEngine
      .MaxLiquidationBonusAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        maxLiquidationBonus: maxLiquidationBonus
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddMaxLiquidationBonusCalled(SPOKE, RESERVE_ID, maxLiquidationBonus);

    engine.executeSpokeMaxLiquidationBonusAdditions(_toMaxLiquidationBonusAdditionArray(addition));
  }

  function test_executeSpokeMaxLiquidationBonusAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addMaxLiquidationBonus.selector, true);

    IAaveV4ConfigEngine.MaxLiquidationBonusAddition
      memory addition = _defaultMaxLiquidationBonusAddition();

    vm.expectRevert(MockSpokeConfigurator.AddMaxLiquidationBonusReverted.selector);
    engine.executeSpokeMaxLiquidationBonusAdditions(_toMaxLiquidationBonusAdditionArray(addition));
  }

  function test_executeSpokeMaxLiquidationBonusUpdates_concrete() public {
    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate
      memory update = _defaultMaxLiquidationBonusUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateMaxLiquidationBonusCalled(
      SPOKE,
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      11000
    );

    engine.executeSpokeMaxLiquidationBonusUpdates(_toMaxLiquidationBonusUpdateArray(update));
  }

  function testFuzz_executeSpokeMaxLiquidationBonusUpdates(
    uint256 dynamicConfigKey,
    uint256 maxLiquidationBonus
  ) public {
    dynamicConfigKey = bound(dynamicConfigKey, 0, type(uint32).max);

    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate memory update = IAaveV4ConfigEngine
      .MaxLiquidationBonusUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfigKey: dynamicConfigKey,
        maxLiquidationBonus: maxLiquidationBonus
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateMaxLiquidationBonusCalled(
      SPOKE,
      RESERVE_ID,
      uint32(dynamicConfigKey),
      maxLiquidationBonus
    );

    engine.executeSpokeMaxLiquidationBonusUpdates(_toMaxLiquidationBonusUpdateArray(update));
  }

  function test_executeSpokeMaxLiquidationBonusUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateMaxLiquidationBonus.selector,
      true
    );

    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate
      memory update = _defaultMaxLiquidationBonusUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateMaxLiquidationBonusReverted.selector);
    engine.executeSpokeMaxLiquidationBonusUpdates(_toMaxLiquidationBonusUpdateArray(update));
  }

  function test_executeSpokeLiquidationFeeAdditions_concrete() public {
    IAaveV4ConfigEngine.LiquidationFeeAddition memory addition = _defaultLiquidationFeeAddition();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddLiquidationFeeCalled(SPOKE, RESERVE_ID, 300);

    engine.executeSpokeLiquidationFeeAdditions(_toLiquidationFeeAdditionArray(addition));
  }

  function testFuzz_executeSpokeLiquidationFeeAdditions(uint256 liquidationFee) public {
    IAaveV4ConfigEngine.LiquidationFeeAddition memory addition = IAaveV4ConfigEngine
      .LiquidationFeeAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        liquidationFee: liquidationFee
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.AddLiquidationFeeCalled(SPOKE, RESERVE_ID, liquidationFee);

    engine.executeSpokeLiquidationFeeAdditions(_toLiquidationFeeAdditionArray(addition));
  }

  function test_executeSpokeLiquidationFeeAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addLiquidationFee.selector, true);

    IAaveV4ConfigEngine.LiquidationFeeAddition memory addition = _defaultLiquidationFeeAddition();

    vm.expectRevert(MockSpokeConfigurator.AddLiquidationFeeReverted.selector);
    engine.executeSpokeLiquidationFeeAdditions(_toLiquidationFeeAdditionArray(addition));
  }

  function test_executeSpokeLiquidationFeeUpdates_concrete() public {
    IAaveV4ConfigEngine.LiquidationFeeUpdate memory update = _defaultLiquidationFeeUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationFeeCalled(
      SPOKE,
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      400
    );

    engine.executeSpokeLiquidationFeeUpdates(_toLiquidationFeeUpdateArray(update));
  }

  function testFuzz_executeSpokeLiquidationFeeUpdates(
    uint256 dynamicConfigKey,
    uint256 liquidationFee
  ) public {
    dynamicConfigKey = bound(dynamicConfigKey, 0, type(uint32).max);

    IAaveV4ConfigEngine.LiquidationFeeUpdate memory update = IAaveV4ConfigEngine
      .LiquidationFeeUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfigKey: dynamicConfigKey,
        liquidationFee: liquidationFee
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdateLiquidationFeeCalled(
      SPOKE,
      RESERVE_ID,
      uint32(dynamicConfigKey),
      liquidationFee
    );

    engine.executeSpokeLiquidationFeeUpdates(_toLiquidationFeeUpdateArray(update));
  }

  function test_executeSpokeLiquidationFeeUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateLiquidationFee.selector, true);

    IAaveV4ConfigEngine.LiquidationFeeUpdate memory update = _defaultLiquidationFeeUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdateLiquidationFeeReverted.selector);
    engine.executeSpokeLiquidationFeeUpdates(_toLiquidationFeeUpdateArray(update));
  }

  function test_executeSpokeAllReservesPauses_concrete() public {
    IAaveV4ConfigEngine.SpokePause memory pause = _defaultSpokePause();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(SPOKE);

    engine.executeSpokeAllReservesPauses(_toSpokePauseArray(pause));
  }

  function testFuzz_executeSpokeAllReservesPauses(address spoke) public {
    IAaveV4ConfigEngine.SpokePause memory pause = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: spoke
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseAllReservesCalled(spoke);

    engine.executeSpokeAllReservesPauses(_toSpokePauseArray(pause));
  }

  function test_executeSpokeAllReservesPauses_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.pauseAllReserves.selector, true);

    IAaveV4ConfigEngine.SpokePause memory pause = _defaultSpokePause();

    vm.expectRevert(MockSpokeConfigurator.PauseAllReservesReverted.selector);
    engine.executeSpokeAllReservesPauses(_toSpokePauseArray(pause));
  }

  function test_executeSpokeAllReservesFreezes_concrete() public {
    IAaveV4ConfigEngine.SpokeFreeze memory freeze = _defaultSpokeFreeze();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeAllReservesCalled(SPOKE);

    engine.executeSpokeAllReservesFreezes(_toSpokeFreezeArray(freeze));
  }

  function testFuzz_executeSpokeAllReservesFreezes(address spoke) public {
    IAaveV4ConfigEngine.SpokeFreeze memory freeze = IAaveV4ConfigEngine.SpokeFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: spoke
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeAllReservesCalled(spoke);

    engine.executeSpokeAllReservesFreezes(_toSpokeFreezeArray(freeze));
  }

  function test_executeSpokeAllReservesFreezes_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.freezeAllReserves.selector, true);

    IAaveV4ConfigEngine.SpokeFreeze memory freeze = _defaultSpokeFreeze();

    vm.expectRevert(MockSpokeConfigurator.FreezeAllReservesReverted.selector);
    engine.executeSpokeAllReservesFreezes(_toSpokeFreezeArray(freeze));
  }

  function test_executeSpokeReservePauses_concrete() public {
    IAaveV4ConfigEngine.ReservePause memory pause = _defaultReservePause();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseReserveCalled(SPOKE, RESERVE_ID);

    engine.executeSpokeReservePauses(_toReservePauseArray(pause));
  }

  function testFuzz_executeSpokeReservePauses(uint256 reserveId) public {
    IAaveV4ConfigEngine.ReservePause memory pause = IAaveV4ConfigEngine.ReservePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: reserveId
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.PauseReserveCalled(SPOKE, reserveId);

    engine.executeSpokeReservePauses(_toReservePauseArray(pause));
  }

  function test_executeSpokeReservePauses_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.pauseReserve.selector, true);

    IAaveV4ConfigEngine.ReservePause memory pause = _defaultReservePause();

    vm.expectRevert(MockSpokeConfigurator.PauseReserveReverted.selector);
    engine.executeSpokeReservePauses(_toReservePauseArray(pause));
  }

  function test_executeSpokeReserveFreezes_concrete() public {
    IAaveV4ConfigEngine.ReserveFreeze memory freeze = _defaultReserveFreeze();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeReserveCalled(SPOKE, RESERVE_ID);

    engine.executeSpokeReserveFreezes(_toReserveFreezeArray(freeze));
  }

  function testFuzz_executeSpokeReserveFreezes(uint256 reserveId) public {
    IAaveV4ConfigEngine.ReserveFreeze memory freeze = IAaveV4ConfigEngine.ReserveFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: reserveId
    });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.FreezeReserveCalled(SPOKE, reserveId);

    engine.executeSpokeReserveFreezes(_toReserveFreezeArray(freeze));
  }

  function test_executeSpokeReserveFreezes_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.freezeReserve.selector, true);

    IAaveV4ConfigEngine.ReserveFreeze memory freeze = _defaultReserveFreeze();

    vm.expectRevert(MockSpokeConfigurator.FreezeReserveReverted.selector);
    engine.executeSpokeReserveFreezes(_toReserveFreezeArray(freeze));
  }

  function test_executeSpokePositionManagerUpdates_concrete() public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePositionManagerCalled(SPOKE, POSITION_MANAGER, true);

    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }

  function testFuzz_executeSpokePositionManagerUpdates(
    address positionManager,
    bool active
  ) public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = IAaveV4ConfigEngine
      .PositionManagerUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        positionManager: positionManager,
        active: active
      });

    vm.expectEmit(address(mockSpokeConfigurator));
    emit MockSpokeConfigurator.UpdatePositionManagerCalled(SPOKE, positionManager, active);

    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }

  function test_executeSpokePositionManagerUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updatePositionManager.selector, true);

    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectRevert(MockSpokeConfigurator.UpdatePositionManagerReverted.selector);
    engine.executeSpokePositionManagerUpdates(_toPositionManagerUpdateArray(update));
  }
}
