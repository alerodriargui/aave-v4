// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

/// @title SpokeEngine
/// @author Aave Labs
/// @notice Library containing spoke configurator logic for AaveV4ConfigEngine.
library SpokeEngine {
  using SafeCast for uint256;

  /// @notice Lists new reserves on spokes.
  /// @param listings The reserve listings to execute.
  function executeSpokeReserveListings(
    IAaveV4ConfigEngine.ReserveListing[] calldata listings
  ) external {
    uint256 length = listings.length;
    for (uint256 i; i < length; ++i) {
      listings[i].spokeConfigurator.addReserve(
        listings[i].spoke,
        listings[i].hub,
        listings[i].assetId,
        listings[i].priceSource,
        listings[i].config,
        listings[i].dynamicConfig
      );
    }
  }

  /// @notice Updates reserve config on spokes.
  /// @param updates The reserve config updates to execute.
  function executeSpokeReserveConfigUpdates(
    IAaveV4ConfigEngine.ReserveConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      if (updates[i].collateralRisk != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateCollateralRisk(
          updates[i].spoke,
          updates[i].reserveId,
          updates[i].collateralRisk
        );
      }
      if (updates[i].paused != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updatePaused(
          updates[i].spoke,
          updates[i].reserveId,
          EngineFlags.toBool(updates[i].paused)
        );
      }
      if (updates[i].frozen != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateFrozen(
          updates[i].spoke,
          updates[i].reserveId,
          EngineFlags.toBool(updates[i].frozen)
        );
      }
      if (updates[i].borrowable != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateBorrowable(
          updates[i].spoke,
          updates[i].reserveId,
          EngineFlags.toBool(updates[i].borrowable)
        );
      }
      if (updates[i].receiveSharesEnabled != EngineFlags.KEEP_CURRENT) {
        updates[i].spokeConfigurator.updateReceiveSharesEnabled(
          updates[i].spoke,
          updates[i].reserveId,
          EngineFlags.toBool(updates[i].receiveSharesEnabled)
        );
      }
    }
  }

  /// @notice Updates reserve price sources on spokes.
  /// @param updates The reserve price source updates to execute.
  function executeSpokeReservePriceSourceUpdates(
    IAaveV4ConfigEngine.ReservePriceSourceUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].spokeConfigurator.updateReservePriceSource(
        updates[i].spoke,
        updates[i].reserveId,
        updates[i].priceSource
      );
    }
  }

  /// @notice Updates liquidation config on spokes.
  /// @dev If all three fields (targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor)
  ///   are set, calls updateLiquidationConfig with the full struct. Otherwise, each non-KEEP_CURRENT
  ///   field is updated individually via its dedicated setter. If no field is set, the update is skipped.
  /// @param updates The liquidation config updates to execute.
  function executeSpokeLiquidationConfigUpdates(
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      bool updateTarget = updates[i].targetHealthFactor != EngineFlags.KEEP_CURRENT;
      bool updateMaxBonus = updates[i].healthFactorForMaxBonus != EngineFlags.KEEP_CURRENT;
      bool updateBonusFactor = updates[i].liquidationBonusFactor != EngineFlags.KEEP_CURRENT;

      if (updateTarget && updateMaxBonus && updateBonusFactor) {
        updates[i].spokeConfigurator.updateLiquidationConfig(
          updates[i].spoke,
          ISpoke.LiquidationConfig({
            targetHealthFactor: updates[i].targetHealthFactor.toUint128(),
            healthFactorForMaxBonus: updates[i].healthFactorForMaxBonus.toUint64(),
            liquidationBonusFactor: updates[i].liquidationBonusFactor.toUint16()
          })
        );
      } else {
        if (updateTarget) {
          updates[i].spokeConfigurator.updateLiquidationTargetHealthFactor(
            updates[i].spoke,
            updates[i].targetHealthFactor
          );
        }
        if (updateMaxBonus) {
          updates[i].spokeConfigurator.updateHealthFactorForMaxBonus(
            updates[i].spoke,
            updates[i].healthFactorForMaxBonus
          );
        }
        if (updateBonusFactor) {
          updates[i].spokeConfigurator.updateLiquidationBonusFactor(
            updates[i].spoke,
            updates[i].liquidationBonusFactor
          );
        }
      }
    }
  }

  /// @notice Adds dynamic reserve configs on spokes.
  /// @param additions The dynamic reserve config additions to execute.
  function executeSpokeDynamicReserveConfigAdditions(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].spokeConfigurator.addDynamicReserveConfig(
        additions[i].spoke,
        additions[i].reserveId,
        additions[i].dynamicConfig
      );
    }
  }

  /// @notice Updates dynamic reserve configs on spokes.
  /// @dev Reads the current config, applies only the fields that differ from KEEP_CURRENT,
  ///   and writes back. If no field is modified the external call is skipped entirely.
  /// @param updates The dynamic reserve config updates to execute.
  function executeSpokeDynamicReserveConfigUpdates(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      bool anyUpdated;

      ISpoke.DynamicReserveConfig memory current = ISpoke(updates[i].spoke).getDynamicReserveConfig(
        updates[i].reserveId,
        updates[i].dynamicConfigKey.toUint32()
      );

      if (updates[i].collateralFactor != EngineFlags.KEEP_CURRENT) {
        current.collateralFactor = updates[i].collateralFactor.toUint16();
        anyUpdated = true;
      }
      if (updates[i].maxLiquidationBonus != EngineFlags.KEEP_CURRENT) {
        current.maxLiquidationBonus = updates[i].maxLiquidationBonus.toUint32();
        anyUpdated = true;
      }
      if (updates[i].liquidationFee != EngineFlags.KEEP_CURRENT) {
        current.liquidationFee = updates[i].liquidationFee.toUint16();
        anyUpdated = true;
      }

      if (!anyUpdated) continue;

      updates[i].spokeConfigurator.updateDynamicReserveConfig(
        updates[i].spoke,
        updates[i].reserveId,
        updates[i].dynamicConfigKey.toUint32(),
        current
      );
    }
  }

  /// @notice Adds collateral factors on spokes.
  /// @param additions The collateral factor additions to execute.
  function executeSpokeCollateralFactorAdditions(
    IAaveV4ConfigEngine.CollateralFactorAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].spokeConfigurator.addCollateralFactor(
        additions[i].spoke,
        additions[i].reserveId,
        additions[i].collateralFactor.toUint16()
      );
    }
  }

  /// @notice Updates collateral factors on spokes.
  /// @param updates The collateral factor updates to execute.
  function executeSpokeCollateralFactorUpdates(
    IAaveV4ConfigEngine.CollateralFactorUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].spokeConfigurator.updateCollateralFactor(
        updates[i].spoke,
        updates[i].reserveId,
        updates[i].dynamicConfigKey.toUint32(),
        updates[i].collateralFactor.toUint16()
      );
    }
  }

  /// @notice Adds max liquidation bonuses on spokes.
  /// @param additions The max liquidation bonus additions to execute.
  function executeSpokeMaxLiquidationBonusAdditions(
    IAaveV4ConfigEngine.MaxLiquidationBonusAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].spokeConfigurator.addMaxLiquidationBonus(
        additions[i].spoke,
        additions[i].reserveId,
        additions[i].maxLiquidationBonus
      );
    }
  }

  /// @notice Updates max liquidation bonuses on spokes.
  /// @param updates The max liquidation bonus updates to execute.
  function executeSpokeMaxLiquidationBonusUpdates(
    IAaveV4ConfigEngine.MaxLiquidationBonusUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].spokeConfigurator.updateMaxLiquidationBonus(
        updates[i].spoke,
        updates[i].reserveId,
        updates[i].dynamicConfigKey.toUint32(),
        updates[i].maxLiquidationBonus
      );
    }
  }

  /// @notice Adds liquidation fees on spokes.
  /// @param additions The liquidation fee additions to execute.
  function executeSpokeLiquidationFeeAdditions(
    IAaveV4ConfigEngine.LiquidationFeeAddition[] calldata additions
  ) external {
    uint256 length = additions.length;
    for (uint256 i; i < length; ++i) {
      additions[i].spokeConfigurator.addLiquidationFee(
        additions[i].spoke,
        additions[i].reserveId,
        additions[i].liquidationFee
      );
    }
  }

  /// @notice Updates liquidation fees on spokes.
  /// @param updates The liquidation fee updates to execute.
  function executeSpokeLiquidationFeeUpdates(
    IAaveV4ConfigEngine.LiquidationFeeUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].spokeConfigurator.updateLiquidationFee(
        updates[i].spoke,
        updates[i].reserveId,
        updates[i].dynamicConfigKey.toUint32(),
        updates[i].liquidationFee
      );
    }
  }

  /// @notice Pauses all reserves on spokes.
  /// @param pauses The spoke pauses to execute.
  function executeSpokeAllReservesPauses(
    IAaveV4ConfigEngine.SpokePause[] calldata pauses
  ) external {
    uint256 length = pauses.length;
    for (uint256 i; i < length; ++i) {
      pauses[i].spokeConfigurator.pauseAllReserves(pauses[i].spoke);
    }
  }

  /// @notice Freezes all reserves on spokes.
  /// @param freezes The spoke freezes to execute.
  function executeSpokeAllReservesFreezes(
    IAaveV4ConfigEngine.SpokeFreeze[] calldata freezes
  ) external {
    uint256 length = freezes.length;
    for (uint256 i; i < length; ++i) {
      freezes[i].spokeConfigurator.freezeAllReserves(freezes[i].spoke);
    }
  }

  /// @notice Pauses individual reserves on spokes.
  /// @param pauses The reserve pauses to execute.
  function executeSpokeReservePauses(IAaveV4ConfigEngine.ReservePause[] calldata pauses) external {
    uint256 length = pauses.length;
    for (uint256 i; i < length; ++i) {
      pauses[i].spokeConfigurator.pauseReserve(pauses[i].spoke, pauses[i].reserveId);
    }
  }

  /// @notice Freezes individual reserves on spokes.
  /// @param freezes The reserve freezes to execute.
  function executeSpokeReserveFreezes(
    IAaveV4ConfigEngine.ReserveFreeze[] calldata freezes
  ) external {
    uint256 length = freezes.length;
    for (uint256 i; i < length; ++i) {
      freezes[i].spokeConfigurator.freezeReserve(freezes[i].spoke, freezes[i].reserveId);
    }
  }

  /// @notice Updates position managers on spokes.
  /// @param updates The position manager updates to execute.
  function executeSpokePositionManagerUpdates(
    IAaveV4ConfigEngine.PositionManagerUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      updates[i].spokeConfigurator.updatePositionManager(
        updates[i].spoke,
        updates[i].positionManager,
        updates[i].active
      );
    }
  }
}
