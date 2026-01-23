// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {ReserveFlags, ReserveFlagsMap} from 'src/spoke/libraries/ReserveFlagsMap.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title ValidationLogic library
/// @author Aave Labs
/// @notice Implements validation logic for Spoke operations.
library ValidationLogic {
  using PercentageMath for uint256;
  using ReserveFlagsMap for ReserveFlags;

  /// @notice Validates the supply operation.
  function validateSupply(ReserveFlags flags) internal pure {
    require(!flags.paused(), ISpoke.ReservePaused());
    require(!flags.frozen(), ISpoke.ReserveFrozen());
  }

  /// @notice Validates the withdraw operation.
  function validateWithdraw(ReserveFlags flags) internal pure {
    require(!flags.paused(), ISpoke.ReservePaused());
  }

  /// @notice Validates the borrow operation.
  function validateBorrow(ReserveFlags flags) internal pure {
    require(!flags.paused(), ISpoke.ReservePaused());
    require(!flags.frozen(), ISpoke.ReserveFrozen());
    require(flags.borrowable(), ISpoke.ReserveNotBorrowable());
    // health factor is checked at the end of borrow action
  }

  /// @notice Validates the repay operation.
  function validateRepay(ReserveFlags flags) internal pure {
    require(!flags.paused(), ISpoke.ReservePaused());
  }

  /// @notice Validates the set using as collateral operation.
  function validateSetUsingAsCollateral(ReserveFlags flags) internal pure {
    require(!flags.paused(), ISpoke.ReservePaused());
  }

  /// @notice Validates the reserve configuration.
  function validateReserveConfig(
    ISpoke.ReserveConfig calldata config,
    uint24 maxAllowedCollateralRisk
  ) internal pure {
    require(config.collateralRisk <= maxAllowedCollateralRisk, ISpoke.InvalidCollateralRisk());
  }

  /// @notice Validates the dynamic reserve configuration.
  /// @dev Enforces compatible `maxLiquidationBonus` and `collateralFactor` so at the moment debt is created
  /// there is enough collateral to cover liquidation.
  function validateDynamicReserveConfig(ISpoke.DynamicReserveConfig calldata config) internal pure {
    require(
      config.collateralFactor < PercentageMath.PERCENTAGE_FACTOR &&
        config.maxLiquidationBonus >= PercentageMath.PERCENTAGE_FACTOR &&
        uint256(config.maxLiquidationBonus).percentMulUp(config.collateralFactor) <
          PercentageMath.PERCENTAGE_FACTOR,
      ISpoke.InvalidCollateralFactorAndMaxLiquidationBonus()
    );
    require(
      config.liquidationFee <= PercentageMath.PERCENTAGE_FACTOR,
      ISpoke.InvalidLiquidationFee()
    );
  }
}
