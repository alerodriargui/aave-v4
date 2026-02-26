// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract MockSpokeConfigurator is ISpokeConfigurator {
  // Per-function revert toggle
  mapping(bytes4 => bool) public shouldRevert;

  string public constant REVERT_MSG = 'MOCK_REVERT';

  function setShouldRevert(bytes4 selector, bool revert_) external {
    shouldRevert[selector] = revert_;
  }

  modifier maybeRevert() {
    if (shouldRevert[msg.sig]) revert(REVERT_MSG);
    _;
  }

  // Events
  event UpdateReservePriceSourceCalled(address spoke, uint256 reserveId, address priceSource);

  event UpdateLiquidationTargetHealthFactorCalled(address spoke, uint256 targetHealthFactor);

  event UpdateHealthFactorForMaxBonusCalled(address spoke, uint256 healthFactorForMaxBonus);

  event UpdateLiquidationBonusFactorCalled(address spoke, uint256 liquidationBonusFactor);

  event UpdateLiquidationConfigCalled(
    address spoke,
    uint128 targetHealthFactor,
    uint64 healthFactorForMaxBonus,
    uint16 liquidationBonusFactor
  );

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

  event UpdatePausedCalled(address spoke, uint256 reserveId, bool paused);

  event UpdateFrozenCalled(address spoke, uint256 reserveId, bool frozen);

  event UpdateBorrowableCalled(address spoke, uint256 reserveId, bool borrowable);

  event UpdateReceiveSharesEnabledCalled(
    address spoke,
    uint256 reserveId,
    bool receiveSharesEnabled
  );

  event UpdateCollateralRiskCalled(address spoke, uint256 reserveId, uint256 collateralRisk);

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

  event PauseAllReservesCalled(address spoke);

  event FreezeAllReservesCalled(address spoke);

  event PauseReserveCalled(address spoke, uint256 reserveId);

  event FreezeReserveCalled(address spoke, uint256 reserveId);

  event UpdatePositionManagerCalled(address spoke, address positionManager, bool active);

  // Implementations

  function updateReservePriceSource(
    address spoke,
    uint256 reserveId,
    address priceSource
  ) external maybeRevert {
    emit UpdateReservePriceSourceCalled(spoke, reserveId, priceSource);
  }

  function updateLiquidationTargetHealthFactor(
    address spoke,
    uint256 targetHealthFactor
  ) external maybeRevert {
    emit UpdateLiquidationTargetHealthFactorCalled(spoke, targetHealthFactor);
  }

  function updateHealthFactorForMaxBonus(
    address spoke,
    uint256 healthFactorForMaxBonus
  ) external maybeRevert {
    emit UpdateHealthFactorForMaxBonusCalled(spoke, healthFactorForMaxBonus);
  }

  function updateLiquidationBonusFactor(
    address spoke,
    uint256 liquidationBonusFactor
  ) external maybeRevert {
    emit UpdateLiquidationBonusFactorCalled(spoke, liquidationBonusFactor);
  }

  function updateLiquidationConfig(
    address spoke,
    ISpoke.LiquidationConfig calldata liquidationConfig
  ) external maybeRevert {
    emit UpdateLiquidationConfigCalled(
      spoke,
      liquidationConfig.targetHealthFactor,
      liquidationConfig.healthFactorForMaxBonus,
      liquidationConfig.liquidationBonusFactor
    );
  }

  function addReserve(
    address spoke,
    address hub,
    uint256 assetId,
    address priceSource,
    ISpoke.ReserveConfig calldata config,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external maybeRevert returns (uint256) {
    emit AddReserveCalled(
      spoke,
      hub,
      assetId,
      priceSource,
      config.collateralRisk,
      config.paused,
      config.frozen,
      config.borrowable,
      config.receiveSharesEnabled,
      dynamicConfig.collateralFactor,
      dynamicConfig.maxLiquidationBonus,
      dynamicConfig.liquidationFee
    );
    return 0;
  }

  function updatePaused(address spoke, uint256 reserveId, bool paused) external maybeRevert {
    emit UpdatePausedCalled(spoke, reserveId, paused);
  }

  function updateFrozen(address spoke, uint256 reserveId, bool frozen) external maybeRevert {
    emit UpdateFrozenCalled(spoke, reserveId, frozen);
  }

  function updateBorrowable(
    address spoke,
    uint256 reserveId,
    bool borrowable
  ) external maybeRevert {
    emit UpdateBorrowableCalled(spoke, reserveId, borrowable);
  }

  function updateReceiveSharesEnabled(
    address spoke,
    uint256 reserveId,
    bool receiveSharesEnabled
  ) external maybeRevert {
    emit UpdateReceiveSharesEnabledCalled(spoke, reserveId, receiveSharesEnabled);
  }

  function updateCollateralRisk(
    address spoke,
    uint256 reserveId,
    uint256 collateralRisk
  ) external maybeRevert {
    emit UpdateCollateralRiskCalled(spoke, reserveId, collateralRisk);
  }

  function addCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external maybeRevert returns (uint32) {
    emit AddCollateralFactorCalled(spoke, reserveId, collateralFactor);
    return 0;
  }

  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint16 collateralFactor
  ) external maybeRevert {
    emit UpdateCollateralFactorCalled(spoke, reserveId, dynamicConfigKey, collateralFactor);
  }

  function addMaxLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 maxLiquidationBonus
  ) external maybeRevert returns (uint32) {
    emit AddMaxLiquidationBonusCalled(spoke, reserveId, maxLiquidationBonus);
    return 0;
  }

  function updateMaxLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint256 maxLiquidationBonus
  ) external maybeRevert {
    emit UpdateMaxLiquidationBonusCalled(spoke, reserveId, dynamicConfigKey, maxLiquidationBonus);
  }

  function addLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint256 liquidationFee
  ) external maybeRevert returns (uint32) {
    emit AddLiquidationFeeCalled(spoke, reserveId, liquidationFee);
    return 0;
  }

  function updateLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint256 liquidationFee
  ) external maybeRevert {
    emit UpdateLiquidationFeeCalled(spoke, reserveId, dynamicConfigKey, liquidationFee);
  }

  function addDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external maybeRevert returns (uint32) {
    emit AddDynamicReserveConfigCalled(
      spoke,
      reserveId,
      dynamicConfig.collateralFactor,
      dynamicConfig.maxLiquidationBonus,
      dynamicConfig.liquidationFee
    );
    return 0;
  }

  function updateDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external maybeRevert {
    emit UpdateDynamicReserveConfigCalled(
      spoke,
      reserveId,
      dynamicConfigKey,
      dynamicConfig.collateralFactor,
      dynamicConfig.maxLiquidationBonus,
      dynamicConfig.liquidationFee
    );
  }

  function pauseAllReserves(address spoke) external maybeRevert {
    emit PauseAllReservesCalled(spoke);
  }

  function freezeAllReserves(address spoke) external maybeRevert {
    emit FreezeAllReservesCalled(spoke);
  }

  function pauseReserve(address spoke, uint256 reserveId) external maybeRevert {
    emit PauseReserveCalled(spoke, reserveId);
  }

  function freezeReserve(address spoke, uint256 reserveId) external maybeRevert {
    emit FreezeReserveCalled(spoke, reserveId);
  }

  function updatePositionManager(
    address spoke,
    address positionManager,
    bool active
  ) external maybeRevert {
    emit UpdatePositionManagerCalled(spoke, positionManager, active);
  }
}
