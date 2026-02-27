// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

contract MockSpokeConfigurator is ISpokeConfigurator {
  mapping(bytes4 => bool) public shouldRevert;

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

  error UpdateReservePriceSourceReverted();
  error UpdateLiquidationTargetHealthFactorReverted();
  error UpdateHealthFactorForMaxBonusReverted();
  error UpdateLiquidationBonusFactorReverted();
  error UpdateLiquidationConfigReverted();
  error AddReserveReverted();
  error UpdatePausedReverted();
  error UpdateFrozenReverted();
  error UpdateBorrowableReverted();
  error UpdateReceiveSharesEnabledReverted();
  error UpdateCollateralRiskReverted();
  error AddCollateralFactorReverted();
  error UpdateCollateralFactorReverted();
  error AddMaxLiquidationBonusReverted();
  error UpdateMaxLiquidationBonusReverted();
  error AddLiquidationFeeReverted();
  error UpdateLiquidationFeeReverted();
  error AddDynamicReserveConfigReverted();
  error UpdateDynamicReserveConfigReverted();
  error PauseAllReservesReverted();
  error FreezeAllReservesReverted();
  error PauseReserveReverted();
  error FreezeReserveReverted();
  error UpdatePositionManagerReverted();

  function setShouldRevert(bytes4 selector, bool revert_) external {
    shouldRevert[selector] = revert_;
  }

  function updateReservePriceSource(
    address spoke,
    uint256 reserveId,
    address priceSource
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateReservePriceSourceReverted();
    emit UpdateReservePriceSourceCalled(spoke, reserveId, priceSource);
  }

  function updateLiquidationTargetHealthFactor(address spoke, uint256 targetHealthFactor) external {
    if (shouldRevert[msg.sig]) revert UpdateLiquidationTargetHealthFactorReverted();
    emit UpdateLiquidationTargetHealthFactorCalled(spoke, targetHealthFactor);
  }

  function updateHealthFactorForMaxBonus(address spoke, uint256 healthFactorForMaxBonus) external {
    if (shouldRevert[msg.sig]) revert UpdateHealthFactorForMaxBonusReverted();
    emit UpdateHealthFactorForMaxBonusCalled(spoke, healthFactorForMaxBonus);
  }

  function updateLiquidationBonusFactor(address spoke, uint256 liquidationBonusFactor) external {
    if (shouldRevert[msg.sig]) revert UpdateLiquidationBonusFactorReverted();
    emit UpdateLiquidationBonusFactorCalled(spoke, liquidationBonusFactor);
  }

  function updateLiquidationConfig(
    address spoke,
    ISpoke.LiquidationConfig calldata liquidationConfig
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateLiquidationConfigReverted();
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
  ) external returns (uint256) {
    if (shouldRevert[msg.sig]) revert AddReserveReverted();
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

  function updatePaused(address spoke, uint256 reserveId, bool paused) external {
    if (shouldRevert[msg.sig]) revert UpdatePausedReverted();
    emit UpdatePausedCalled(spoke, reserveId, paused);
  }

  function updateFrozen(address spoke, uint256 reserveId, bool frozen) external {
    if (shouldRevert[msg.sig]) revert UpdateFrozenReverted();
    emit UpdateFrozenCalled(spoke, reserveId, frozen);
  }

  function updateBorrowable(address spoke, uint256 reserveId, bool borrowable) external {
    if (shouldRevert[msg.sig]) revert UpdateBorrowableReverted();
    emit UpdateBorrowableCalled(spoke, reserveId, borrowable);
  }

  function updateReceiveSharesEnabled(
    address spoke,
    uint256 reserveId,
    bool receiveSharesEnabled
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateReceiveSharesEnabledReverted();
    emit UpdateReceiveSharesEnabledCalled(spoke, reserveId, receiveSharesEnabled);
  }

  function updateCollateralRisk(address spoke, uint256 reserveId, uint256 collateralRisk) external {
    if (shouldRevert[msg.sig]) revert UpdateCollateralRiskReverted();
    emit UpdateCollateralRiskCalled(spoke, reserveId, collateralRisk);
  }

  function addCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint16 collateralFactor
  ) external returns (uint32) {
    if (shouldRevert[msg.sig]) revert AddCollateralFactorReverted();
    emit AddCollateralFactorCalled(spoke, reserveId, collateralFactor);
    return 0;
  }

  function updateCollateralFactor(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint16 collateralFactor
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateCollateralFactorReverted();
    emit UpdateCollateralFactorCalled(spoke, reserveId, dynamicConfigKey, collateralFactor);
  }

  function addMaxLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint256 maxLiquidationBonus
  ) external returns (uint32) {
    if (shouldRevert[msg.sig]) revert AddMaxLiquidationBonusReverted();
    emit AddMaxLiquidationBonusCalled(spoke, reserveId, maxLiquidationBonus);
    return 0;
  }

  function updateMaxLiquidationBonus(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint256 maxLiquidationBonus
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateMaxLiquidationBonusReverted();
    emit UpdateMaxLiquidationBonusCalled(spoke, reserveId, dynamicConfigKey, maxLiquidationBonus);
  }

  function addLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint256 liquidationFee
  ) external returns (uint32) {
    if (shouldRevert[msg.sig]) revert AddLiquidationFeeReverted();
    emit AddLiquidationFeeCalled(spoke, reserveId, liquidationFee);
    return 0;
  }

  function updateLiquidationFee(
    address spoke,
    uint256 reserveId,
    uint32 dynamicConfigKey,
    uint256 liquidationFee
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateLiquidationFeeReverted();
    emit UpdateLiquidationFeeCalled(spoke, reserveId, dynamicConfigKey, liquidationFee);
  }

  function addDynamicReserveConfig(
    address spoke,
    uint256 reserveId,
    ISpoke.DynamicReserveConfig calldata dynamicConfig
  ) external returns (uint32) {
    if (shouldRevert[msg.sig]) revert AddDynamicReserveConfigReverted();
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
  ) external {
    if (shouldRevert[msg.sig]) revert UpdateDynamicReserveConfigReverted();
    emit UpdateDynamicReserveConfigCalled(
      spoke,
      reserveId,
      dynamicConfigKey,
      dynamicConfig.collateralFactor,
      dynamicConfig.maxLiquidationBonus,
      dynamicConfig.liquidationFee
    );
  }

  function pauseAllReserves(address spoke) external {
    if (shouldRevert[msg.sig]) revert PauseAllReservesReverted();
    emit PauseAllReservesCalled(spoke);
  }

  function freezeAllReserves(address spoke) external {
    if (shouldRevert[msg.sig]) revert FreezeAllReservesReverted();
    emit FreezeAllReservesCalled(spoke);
  }

  function pauseReserve(address spoke, uint256 reserveId) external {
    if (shouldRevert[msg.sig]) revert PauseReserveReverted();
    emit PauseReserveCalled(spoke, reserveId);
  }

  function freezeReserve(address spoke, uint256 reserveId) external {
    if (shouldRevert[msg.sig]) revert FreezeReserveReverted();
    emit FreezeReserveCalled(spoke, reserveId);
  }

  function updatePositionManager(address spoke, address positionManager, bool active) external {
    if (shouldRevert[msg.sig]) revert UpdatePositionManagerReverted();
    emit UpdatePositionManagerCalled(spoke, positionManager, active);
  }
}
