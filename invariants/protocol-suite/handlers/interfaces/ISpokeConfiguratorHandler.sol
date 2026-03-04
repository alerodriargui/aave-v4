// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title ISpokeConfiguratorHandler
/// @notice Interface for the SpokeConfiguratorHandler
interface ISpokeConfiguratorHandler {
  function updateLiquidationTargetHealthFactor(uint256 targetHealthFactor, uint8 i) external;

  function updateHealthFactorForMaxBonus(uint256 healthFactorForMaxBonus, uint8 i) external;

  function updateLiquidationBonusFactor(uint256 liquidationBonusFactor, uint8 i) external;

  function updatePaused(bool halted, uint8 i, uint8 j) external;

  function updateFrozen(bool frozen, uint8 i, uint8 j) external;

  function updateBorrowable(bool borrowable, uint8 i, uint8 j) external;

  function pauseAllReserves(uint8 i) external;

  function freezeAllReserves(uint8 i) external;
}
