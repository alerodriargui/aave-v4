// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/EngineFlags.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {MockSpokeConfigurator} from 'tests/mocks/config-engine/MockSpokeConfigurator.sol';
import {MockSpokeReader} from 'tests/mocks/config-engine/MockSpokeReader.sol';

contract SpokeEngineTest is BaseConfigEngineTest {
  // ============================================================
  // Re-declare mock events for vm.expectEmit
  // ============================================================

  event AddReserveCalled(
    address spoke,
    address hub,
    uint256 assetId,
    address priceSource,
    uint24 collateralRisk,
    bool paused,
    bool frozen,
    bool borrowable,
    bool receiveSharesEnabled,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  );

  event UpdateReservePriceSourceCalled(address spoke, uint256 reserveId, address priceSource);

  event UpdateCollateralRiskCalled(address spoke, uint256 reserveId, uint256 collateralRisk);
  event UpdatePausedCalled(address spoke, uint256 reserveId, bool paused);
  event UpdateFrozenCalled(address spoke, uint256 reserveId, bool frozen);
  event UpdateBorrowableCalled(address spoke, uint256 reserveId, bool borrowable);
  event UpdateReceiveSharesEnabledCalled(
    address spoke,
    uint256 reserveId,
    bool receiveSharesEnabled
  );

  event UpdateLiquidationConfigCalled(
    address spoke,
    uint128 targetHealthFactor,
    uint64 healthFactorForMaxBonus,
    uint16 liquidationBonusFactor
  );
  event UpdateLiquidationTargetHealthFactorCalled(address spoke, uint256 targetHealthFactor);
  event UpdateHealthFactorForMaxBonusCalled(address spoke, uint256 healthFactorForMaxBonus);
  event UpdateLiquidationBonusFactorCalled(address spoke, uint256 liquidationBonusFactor);

  event AddDynamicReserveConfigCalled(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  );

  event UpdateDynamicReserveConfigCalled(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint16 collateralFactor,
    uint32 maxLiquidationBonus,
    uint16 liquidationFee
  );

  event AddCollateralFactorCalled(address spoke, uint256 reserveId, uint16 collateralFactor);
  event UpdateCollateralFactorCalled(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint16 collateralFactor
  );

  event AddMaxLiquidationBonusCalled(address spoke, uint256 reserveId, uint256 maxLiquidationBonus);
  event UpdateMaxLiquidationBonusCalled(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint256 maxLiquidationBonus
  );

  event AddLiquidationFeeCalled(address spoke, uint256 reserveId, uint256 liquidationFee);
  event UpdateLiquidationFeeCalled(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint256 liquidationFee
  );

  event PauseAllReservesCalled(address spoke);
  event FreezeAllReservesCalled(address spoke);
  event PauseReserveCalled(address spoke, uint256 reserveId);
  event FreezeReserveCalled(address spoke, uint256 reserveId);
  event UpdatePositionManagerCalled(address spoke, address positionManager, bool active);

  // ============================================================
  // Array helpers for types not in BaseConfigEngineTest
  // ============================================================

  function _toArray(
    IAaveV4ConfigEngine.ReserveListing memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReserveListing[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReserveListing[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.ReservePriceSourceUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReservePriceSourceUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReservePriceSourceUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition memory item
  ) internal pure returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory arr) {
    arr = new IAaveV4ConfigEngine.DynamicReserveConfigAddition[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.CollateralFactorAddition memory item
  ) internal pure returns (IAaveV4ConfigEngine.CollateralFactorAddition[] memory arr) {
    arr = new IAaveV4ConfigEngine.CollateralFactorAddition[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.CollateralFactorUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.CollateralFactorUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.CollateralFactorUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition memory item
  ) internal pure returns (IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] memory arr) {
    arr = new IAaveV4ConfigEngine.MaxLiquidationBonusAddition[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.LiquidationFeeAddition memory item
  ) internal pure returns (IAaveV4ConfigEngine.LiquidationFeeAddition[] memory arr) {
    arr = new IAaveV4ConfigEngine.LiquidationFeeAddition[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.LiquidationFeeUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.LiquidationFeeUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.LiquidationFeeUpdate[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.SpokePause memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokePause[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokePause[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.SpokeFreeze memory item
  ) internal pure returns (IAaveV4ConfigEngine.SpokeFreeze[] memory arr) {
    arr = new IAaveV4ConfigEngine.SpokeFreeze[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.ReservePause memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReservePause[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReservePause[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.ReserveFreeze memory item
  ) internal pure returns (IAaveV4ConfigEngine.ReserveFreeze[] memory arr) {
    arr = new IAaveV4ConfigEngine.ReserveFreeze[](1);
    arr[0] = item;
  }

  function _toArray(
    IAaveV4ConfigEngine.PositionManagerUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.PositionManagerUpdate[](1);
    arr[0] = item;
  }

  // ============================================================
  // Default struct helpers
  // ============================================================

  function _defaultReserveListing()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveListing memory)
  {
    return
      IAaveV4ConfigEngine.ReserveListing({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        hub: HUB,
        assetId: ASSET_ID,
        priceSource: PRICE_SOURCE,
        config: ISpoke.ReserveConfig({
          collateralRisk: 5000,
          paused: false,
          frozen: false,
          borrowable: true,
          receiveSharesEnabled: true
        }),
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 8000,
          maxLiquidationBonus: 10500,
          liquidationFee: 200
        })
      });
  }

  function _defaultReservePriceSourceUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.ReservePriceSourceUpdate memory)
  {
    return
      IAaveV4ConfigEngine.ReservePriceSourceUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        priceSource: PRICE_SOURCE
      });
  }

  function _defaultDynamicReserveConfigAddition()
    internal
    view
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition memory)
  {
    return
      IAaveV4ConfigEngine.DynamicReserveConfigAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfig: ISpoke.DynamicReserveConfig({
          collateralFactor: 8000,
          maxLiquidationBonus: 10500,
          liquidationFee: 200
        })
      });
  }

  function _defaultCollateralFactorAddition()
    internal
    view
    returns (IAaveV4ConfigEngine.CollateralFactorAddition memory)
  {
    return
      IAaveV4ConfigEngine.CollateralFactorAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        collateralFactor: 8000
      });
  }

  function _defaultCollateralFactorUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.CollateralFactorUpdate memory)
  {
    return
      IAaveV4ConfigEngine.CollateralFactorUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        collateralFactor: 9000
      });
  }

  function _defaultMaxLiquidationBonusAddition()
    internal
    view
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusAddition memory)
  {
    return
      IAaveV4ConfigEngine.MaxLiquidationBonusAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        maxLiquidationBonus: 10500
      });
  }

  function _defaultMaxLiquidationBonusUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.MaxLiquidationBonusUpdate memory)
  {
    return
      IAaveV4ConfigEngine.MaxLiquidationBonusUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        maxLiquidationBonus: 11000
      });
  }

  function _defaultLiquidationFeeAddition()
    internal
    view
    returns (IAaveV4ConfigEngine.LiquidationFeeAddition memory)
  {
    return
      IAaveV4ConfigEngine.LiquidationFeeAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        liquidationFee: 300
      });
  }

  function _defaultLiquidationFeeUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.LiquidationFeeUpdate memory)
  {
    return
      IAaveV4ConfigEngine.LiquidationFeeUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        dynamicConfigKey: DYNAMIC_CONFIG_KEY,
        liquidationFee: 400
      });
  }

  function _defaultSpokePause() internal view returns (IAaveV4ConfigEngine.SpokePause memory) {
    return
      IAaveV4ConfigEngine.SpokePause({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE
      });
  }

  function _defaultSpokeFreeze() internal view returns (IAaveV4ConfigEngine.SpokeFreeze memory) {
    return
      IAaveV4ConfigEngine.SpokeFreeze({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE
      });
  }

  function _defaultReservePause() internal view returns (IAaveV4ConfigEngine.ReservePause memory) {
    return
      IAaveV4ConfigEngine.ReservePause({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID
      });
  }

  function _defaultReserveFreeze()
    internal
    view
    returns (IAaveV4ConfigEngine.ReserveFreeze memory)
  {
    return
      IAaveV4ConfigEngine.ReserveFreeze({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID
      });
  }

  function _defaultPositionManagerUpdate()
    internal
    view
    returns (IAaveV4ConfigEngine.PositionManagerUpdate memory)
  {
    return
      IAaveV4ConfigEngine.PositionManagerUpdate({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        positionManager: POSITION_MANAGER,
        active: true
      });
  }

  // ============================================================
  // 1. executeSpokeReserveConfigUpdates
  // ============================================================

  function test_executeSpokeReserveConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, 5000);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdatePausedCalled(SPOKE, RESERVE_ID, false);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateFrozenCalled(SPOKE, RESERVE_ID, false);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateBorrowableCalled(SPOKE, RESERVE_ID, true);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateReceiveSharesEnabledCalled(SPOKE, RESERVE_ID, true);

    engine.executeSpokeReserveConfigUpdates(_toArray(update));
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
    engine.executeSpokeReserveConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, 7500);

    vm.recordLogs();
    engine.executeSpokeReserveConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateCollateralRiskCalled(SPOKE, RESERVE_ID, collateralRisk);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdatePausedCalled(SPOKE, RESERVE_ID, paused_);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateFrozenCalled(SPOKE, RESERVE_ID, frozen_);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateBorrowableCalled(SPOKE, RESERVE_ID, borrowable_);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateReceiveSharesEnabledCalled(SPOKE, RESERVE_ID, receiveSharesEnabled_);

    engine.executeSpokeReserveConfigUpdates(_toArray(update));
  }

  function test_executeSpokeReserveConfigUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateCollateralRisk.selector, true);

    IAaveV4ConfigEngine.ReserveConfigUpdate memory update = _defaultReserveConfigUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeReserveConfigUpdates(_toArray(update));
  }

  // ============================================================
  // 2. executeSpokeLiquidationConfigUpdates
  // ============================================================

  function test_executeSpokeLiquidationConfigUpdates_allSet() public {
    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationConfigCalled(SPOKE, uint128(1.05e18), uint64(0.95e18), uint16(10000));

    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationTargetHealthFactorCalled(SPOKE, 1.05e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateHealthFactorForMaxBonusCalled(SPOKE, 0.95e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationBonusFactorCalled(SPOKE, 10000);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationTargetHealthFactorCalled(SPOKE, 1.05e18);

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateHealthFactorForMaxBonusCalled(SPOKE, 0.95e18);

    vm.recordLogs();
    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
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
    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationConfigCalled(
      SPOKE,
      uint128(targetHealthFactor),
      uint64(healthFactorForMaxBonus),
      uint16(liquidationBonusFactor)
    );

    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
  }

  function test_executeSpokeLiquidationConfigUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateLiquidationConfig.selector,
      true
    );

    IAaveV4ConfigEngine.LiquidationConfigUpdate memory update = _defaultLiquidationConfigUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeLiquidationConfigUpdates(_toArray(update));
  }

  // ============================================================
  // 3. executeSpokeDynamicReserveConfigUpdates
  // ============================================================

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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      8000,
      10500,
      1000
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toArray(update));
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
    engine.executeSpokeDynamicReserveConfigUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateDynamicReserveConfigCalled(
      address(mockSpokeReader),
      RESERVE_ID,
      uint32(DYNAMIC_CONFIG_KEY),
      9000,
      10000,
      500
    );

    engine.executeSpokeDynamicReserveConfigUpdates(_toArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertReader() public {
    mockSpokeReader.setShouldRevertOnRead(true);

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectRevert('MOCK_READ_REVERT');
    engine.executeSpokeDynamicReserveConfigUpdates(_toArray(update));
  }

  function test_executeSpokeDynamicReserveConfigUpdates_revertConfigurator() public {
    _setupDynamicReserveConfig(5000, 10000, 200);

    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateDynamicReserveConfig.selector,
      true
    );

    IAaveV4ConfigEngine.DynamicReserveConfigUpdate
      memory update = _defaultDynamicReserveConfigUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeDynamicReserveConfigUpdates(_toArray(update));
  }

  // ============================================================
  // 4. executeSpokeReserveListings
  // ============================================================

  function test_executeSpokeReserveListings_concrete() public {
    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddReserveCalled(
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

    engine.executeSpokeReserveListings(_toArray(listing));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddReserveCalled(
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

    engine.executeSpokeReserveListings(_toArray(listing));
  }

  function test_executeSpokeReserveListings_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addReserve.selector, true);

    IAaveV4ConfigEngine.ReserveListing memory listing = _defaultReserveListing();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeReserveListings(_toArray(listing));
  }

  // ============================================================
  // 5. executeSpokeReservePriceSourceUpdates
  // ============================================================

  function test_executeSpokeReservePriceSourceUpdates_concrete() public {
    IAaveV4ConfigEngine.ReservePriceSourceUpdate memory update = _defaultReservePriceSourceUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateReservePriceSourceCalled(SPOKE, RESERVE_ID, PRICE_SOURCE);

    engine.executeSpokeReservePriceSourceUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateReservePriceSourceCalled(SPOKE, reserveId, priceSource);

    engine.executeSpokeReservePriceSourceUpdates(_toArray(update));
  }

  function test_executeSpokeReservePriceSourceUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateReservePriceSource.selector,
      true
    );

    IAaveV4ConfigEngine.ReservePriceSourceUpdate memory update = _defaultReservePriceSourceUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeReservePriceSourceUpdates(_toArray(update));
  }

  // ============================================================
  // 6. executeSpokeDynamicReserveConfigAdditions
  // ============================================================

  function test_executeSpokeDynamicReserveConfigAdditions_concrete() public {
    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddDynamicReserveConfigCalled(SPOKE, RESERVE_ID, 8000, 10500, 200);

    engine.executeSpokeDynamicReserveConfigAdditions(_toArray(addition));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddDynamicReserveConfigCalled(
      SPOKE,
      RESERVE_ID,
      collateralFactor,
      maxLiquidationBonus,
      liquidationFee
    );

    engine.executeSpokeDynamicReserveConfigAdditions(_toArray(addition));
  }

  function test_executeSpokeDynamicReserveConfigAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.addDynamicReserveConfig.selector,
      true
    );

    IAaveV4ConfigEngine.DynamicReserveConfigAddition
      memory addition = _defaultDynamicReserveConfigAddition();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeDynamicReserveConfigAdditions(_toArray(addition));
  }

  // ============================================================
  // 7. executeSpokeCollateralFactorAdditions
  // ============================================================

  function test_executeSpokeCollateralFactorAdditions_concrete() public {
    IAaveV4ConfigEngine.CollateralFactorAddition
      memory addition = _defaultCollateralFactorAddition();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddCollateralFactorCalled(SPOKE, RESERVE_ID, 8000);

    engine.executeSpokeCollateralFactorAdditions(_toArray(addition));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddCollateralFactorCalled(SPOKE, RESERVE_ID, uint16(collateralFactor));

    engine.executeSpokeCollateralFactorAdditions(_toArray(addition));
  }

  function test_executeSpokeCollateralFactorAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addCollateralFactor.selector, true);

    IAaveV4ConfigEngine.CollateralFactorAddition
      memory addition = _defaultCollateralFactorAddition();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeCollateralFactorAdditions(_toArray(addition));
  }

  // ============================================================
  // 8. executeSpokeCollateralFactorUpdates
  // ============================================================

  function test_executeSpokeCollateralFactorUpdates_concrete() public {
    IAaveV4ConfigEngine.CollateralFactorUpdate memory update = _defaultCollateralFactorUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateCollateralFactorCalled(SPOKE, RESERVE_ID, uint32(DYNAMIC_CONFIG_KEY), 9000);

    engine.executeSpokeCollateralFactorUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateCollateralFactorCalled(
      SPOKE,
      RESERVE_ID,
      uint32(dynamicConfigKey),
      uint16(collateralFactor)
    );

    engine.executeSpokeCollateralFactorUpdates(_toArray(update));
  }

  function test_executeSpokeCollateralFactorUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateCollateralFactor.selector, true);

    IAaveV4ConfigEngine.CollateralFactorUpdate memory update = _defaultCollateralFactorUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeCollateralFactorUpdates(_toArray(update));
  }

  // ============================================================
  // 9. executeSpokeMaxLiquidationBonusAdditions
  // ============================================================

  function test_executeSpokeMaxLiquidationBonusAdditions_concrete() public {
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition
      memory addition = _defaultMaxLiquidationBonusAddition();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddMaxLiquidationBonusCalled(SPOKE, RESERVE_ID, 10500);

    engine.executeSpokeMaxLiquidationBonusAdditions(_toArray(addition));
  }

  function testFuzz_executeSpokeMaxLiquidationBonusAdditions(uint256 maxLiquidationBonus) public {
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition memory addition = IAaveV4ConfigEngine
      .MaxLiquidationBonusAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        maxLiquidationBonus: maxLiquidationBonus
      });

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddMaxLiquidationBonusCalled(SPOKE, RESERVE_ID, maxLiquidationBonus);

    engine.executeSpokeMaxLiquidationBonusAdditions(_toArray(addition));
  }

  function test_executeSpokeMaxLiquidationBonusAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addMaxLiquidationBonus.selector, true);

    IAaveV4ConfigEngine.MaxLiquidationBonusAddition
      memory addition = _defaultMaxLiquidationBonusAddition();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeMaxLiquidationBonusAdditions(_toArray(addition));
  }

  // ============================================================
  // 10. executeSpokeMaxLiquidationBonusUpdates
  // ============================================================

  function test_executeSpokeMaxLiquidationBonusUpdates_concrete() public {
    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate
      memory update = _defaultMaxLiquidationBonusUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateMaxLiquidationBonusCalled(SPOKE, RESERVE_ID, uint32(DYNAMIC_CONFIG_KEY), 11000);

    engine.executeSpokeMaxLiquidationBonusUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateMaxLiquidationBonusCalled(
      SPOKE,
      RESERVE_ID,
      uint32(dynamicConfigKey),
      maxLiquidationBonus
    );

    engine.executeSpokeMaxLiquidationBonusUpdates(_toArray(update));
  }

  function test_executeSpokeMaxLiquidationBonusUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(
      ISpokeConfigurator.updateMaxLiquidationBonus.selector,
      true
    );

    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate
      memory update = _defaultMaxLiquidationBonusUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeMaxLiquidationBonusUpdates(_toArray(update));
  }

  // ============================================================
  // 11. executeSpokeLiquidationFeeAdditions
  // ============================================================

  function test_executeSpokeLiquidationFeeAdditions_concrete() public {
    IAaveV4ConfigEngine.LiquidationFeeAddition memory addition = _defaultLiquidationFeeAddition();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddLiquidationFeeCalled(SPOKE, RESERVE_ID, 300);

    engine.executeSpokeLiquidationFeeAdditions(_toArray(addition));
  }

  function testFuzz_executeSpokeLiquidationFeeAdditions(uint256 liquidationFee) public {
    IAaveV4ConfigEngine.LiquidationFeeAddition memory addition = IAaveV4ConfigEngine
      .LiquidationFeeAddition({
        spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
        spoke: SPOKE,
        reserveId: RESERVE_ID,
        liquidationFee: liquidationFee
      });

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit AddLiquidationFeeCalled(SPOKE, RESERVE_ID, liquidationFee);

    engine.executeSpokeLiquidationFeeAdditions(_toArray(addition));
  }

  function test_executeSpokeLiquidationFeeAdditions_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.addLiquidationFee.selector, true);

    IAaveV4ConfigEngine.LiquidationFeeAddition memory addition = _defaultLiquidationFeeAddition();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeLiquidationFeeAdditions(_toArray(addition));
  }

  // ============================================================
  // 12. executeSpokeLiquidationFeeUpdates
  // ============================================================

  function test_executeSpokeLiquidationFeeUpdates_concrete() public {
    IAaveV4ConfigEngine.LiquidationFeeUpdate memory update = _defaultLiquidationFeeUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationFeeCalled(SPOKE, RESERVE_ID, uint32(DYNAMIC_CONFIG_KEY), 400);

    engine.executeSpokeLiquidationFeeUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdateLiquidationFeeCalled(SPOKE, RESERVE_ID, uint32(dynamicConfigKey), liquidationFee);

    engine.executeSpokeLiquidationFeeUpdates(_toArray(update));
  }

  function test_executeSpokeLiquidationFeeUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updateLiquidationFee.selector, true);

    IAaveV4ConfigEngine.LiquidationFeeUpdate memory update = _defaultLiquidationFeeUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeLiquidationFeeUpdates(_toArray(update));
  }

  // ============================================================
  // 13. executeSpokeAllReservesPauses
  // ============================================================

  function test_executeSpokeAllReservesPauses_concrete() public {
    IAaveV4ConfigEngine.SpokePause memory pause = _defaultSpokePause();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit PauseAllReservesCalled(SPOKE);

    engine.executeSpokeAllReservesPauses(_toArray(pause));
  }

  function testFuzz_executeSpokeAllReservesPauses(address spoke) public {
    IAaveV4ConfigEngine.SpokePause memory pause = IAaveV4ConfigEngine.SpokePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: spoke
    });

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit PauseAllReservesCalled(spoke);

    engine.executeSpokeAllReservesPauses(_toArray(pause));
  }

  function test_executeSpokeAllReservesPauses_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.pauseAllReserves.selector, true);

    IAaveV4ConfigEngine.SpokePause memory pause = _defaultSpokePause();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeAllReservesPauses(_toArray(pause));
  }

  // ============================================================
  // 14. executeSpokeAllReservesFreezes
  // ============================================================

  function test_executeSpokeAllReservesFreezes_concrete() public {
    IAaveV4ConfigEngine.SpokeFreeze memory freeze = _defaultSpokeFreeze();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit FreezeAllReservesCalled(SPOKE);

    engine.executeSpokeAllReservesFreezes(_toArray(freeze));
  }

  function testFuzz_executeSpokeAllReservesFreezes(address spoke) public {
    IAaveV4ConfigEngine.SpokeFreeze memory freeze = IAaveV4ConfigEngine.SpokeFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: spoke
    });

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit FreezeAllReservesCalled(spoke);

    engine.executeSpokeAllReservesFreezes(_toArray(freeze));
  }

  function test_executeSpokeAllReservesFreezes_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.freezeAllReserves.selector, true);

    IAaveV4ConfigEngine.SpokeFreeze memory freeze = _defaultSpokeFreeze();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeAllReservesFreezes(_toArray(freeze));
  }

  // ============================================================
  // 15. executeSpokeReservePauses
  // ============================================================

  function test_executeSpokeReservePauses_concrete() public {
    IAaveV4ConfigEngine.ReservePause memory pause = _defaultReservePause();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit PauseReserveCalled(SPOKE, RESERVE_ID);

    engine.executeSpokeReservePauses(_toArray(pause));
  }

  function testFuzz_executeSpokeReservePauses(uint256 reserveId) public {
    IAaveV4ConfigEngine.ReservePause memory pause = IAaveV4ConfigEngine.ReservePause({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: reserveId
    });

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit PauseReserveCalled(SPOKE, reserveId);

    engine.executeSpokeReservePauses(_toArray(pause));
  }

  function test_executeSpokeReservePauses_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.pauseReserve.selector, true);

    IAaveV4ConfigEngine.ReservePause memory pause = _defaultReservePause();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeReservePauses(_toArray(pause));
  }

  // ============================================================
  // 16. executeSpokeReserveFreezes
  // ============================================================

  function test_executeSpokeReserveFreezes_concrete() public {
    IAaveV4ConfigEngine.ReserveFreeze memory freeze = _defaultReserveFreeze();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit FreezeReserveCalled(SPOKE, RESERVE_ID);

    engine.executeSpokeReserveFreezes(_toArray(freeze));
  }

  function testFuzz_executeSpokeReserveFreezes(uint256 reserveId) public {
    IAaveV4ConfigEngine.ReserveFreeze memory freeze = IAaveV4ConfigEngine.ReserveFreeze({
      spokeConfigurator: ISpokeConfigurator(address(mockSpokeConfigurator)),
      spoke: SPOKE,
      reserveId: reserveId
    });

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit FreezeReserveCalled(SPOKE, reserveId);

    engine.executeSpokeReserveFreezes(_toArray(freeze));
  }

  function test_executeSpokeReserveFreezes_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.freezeReserve.selector, true);

    IAaveV4ConfigEngine.ReserveFreeze memory freeze = _defaultReserveFreeze();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokeReserveFreezes(_toArray(freeze));
  }

  // ============================================================
  // 17. executeSpokePositionManagerUpdates
  // ============================================================

  function test_executeSpokePositionManagerUpdates_concrete() public {
    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdatePositionManagerCalled(SPOKE, POSITION_MANAGER, true);

    engine.executeSpokePositionManagerUpdates(_toArray(update));
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

    vm.expectEmit(true, true, true, true, address(mockSpokeConfigurator));
    emit UpdatePositionManagerCalled(SPOKE, positionManager, active);

    engine.executeSpokePositionManagerUpdates(_toArray(update));
  }

  function test_executeSpokePositionManagerUpdates_revert() public {
    mockSpokeConfigurator.setShouldRevert(ISpokeConfigurator.updatePositionManager.selector, true);

    IAaveV4ConfigEngine.PositionManagerUpdate memory update = _defaultPositionManagerUpdate();

    vm.expectRevert('MOCK_REVERT');
    engine.executeSpokePositionManagerUpdates(_toArray(update));
  }
}
