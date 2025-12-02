// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {MathUtils} from './MathUtils.sol';

/// @title PercentageMath library
/// @author Aave Labs
/// @notice Provides functions to perform percentage calculations with explicit rounding.
/// @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by `PERCENTAGE_FACTOR`.
library PercentageMath {
  // Maximum percentage factor in BPS (100.00%)
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  /// @notice Executes a percentage multiplication, rounded down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return result = floor(value * percentage / PERCENTAGE_FACTOR)
  function percentMulDown(uint256 value, uint256 percentage) internal pure returns (uint256) {
    return MathUtils.mulDivDown(value, percentage, PERCENTAGE_FACTOR);
  }

  /// @notice Executes a percentage multiplication, rounded up.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return result = ceil(value * percentage / PERCENTAGE_FACTOR)
  function percentMulUp(uint256 value, uint256 percentage) internal pure returns (uint256) {
    return MathUtils.mulDivUp(value, percentage, PERCENTAGE_FACTOR);
  }

  /// @notice Executes a percentage division, rounded down.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return result = floor(value * PERCENTAGE_FACTOR / percentage)
  function percentDivDown(uint256 value, uint256 percentage) internal pure returns (uint256) {
    return MathUtils.mulDivDown(value, PERCENTAGE_FACTOR, percentage);
  }

  /// @notice Executes a percentage division, rounded up.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return result = ceil(value * PERCENTAGE_FACTOR / percentage)
  function percentDivUp(uint256 value, uint256 percentage) internal pure returns (uint256) {
    return MathUtils.mulDivUp(value, PERCENTAGE_FACTOR, percentage);
  }

  /// @notice Truncates number from BPS precision, rounding down.
  function fromBpsDown(uint256 value) internal pure returns (uint256) {
    return value / PERCENTAGE_FACTOR;
  }
}
