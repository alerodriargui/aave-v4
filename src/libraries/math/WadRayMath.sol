// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {MathUtils} from './MathUtils.sol';

/// @title WadRayMath library
/// @author Aave Labs
/// @notice Provides utility functions to work with WAD and RAY units with explicit rounding.
library WadRayMath {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant RAY = 1e27;
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  /// @notice Multiplies two WAD numbers, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = floor(a * b / WAD) in WAD units.
  function wadMulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivDown(a, b, WAD);
  }

  /// @notice Multiplies two WAD numbers, rounding up.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = ceil(a * b / WAD) in WAD units.
  function wadMulUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivUp(a, b, WAD);
  }

  /// @notice Divides two WAD numbers, rounding down.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = floor(a * WAD / b) in WAD units.
  function wadDivDown(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivDown(a, WAD, b);
  }

  /// @notice Divides two WAD numbers, rounding up.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = ceil(a * WAD / b) in WAD units.
  function wadDivUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivUp(a, WAD, b);
  }

  /// @notice Multiplies two RAY numbers, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = floor(a * b / RAY) in RAY units.
  function rayMulDown(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivDown(a, b, RAY);
  }

  /// @notice Multiplies two RAY numbers, rounding up.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return c = ceil(a * b / RAY) in RAY units.
  function rayMulUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivUp(a, b, RAY);
  }

  /// @notice Divides two RAY numbers, rounding down.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = floor(a * RAY / b) in RAY units.
  function rayDivDown(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivDown(a, RAY, b);
  }

  /// @notice Divides two RAY numbers, rounding up.
  /// @dev Reverts if division by zero or intermediate multiplication overflows.
  /// @return c = ceil(a * RAY / b) in RAY units.
  function rayDivUp(uint256 a, uint256 b) internal pure returns (uint256) {
    return MathUtils.mulDivUp(a, RAY, b);
  }

  /// @notice Casts value to WAD, adding 18 digits of precision.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return b = a * WAD in WAD units.
  function toWad(uint256 a) internal pure returns (uint256 b) {
    assembly ('memory-safe') {
      b := mul(a, WAD)

      // to avoid overflow, b/WAD == a
      if iszero(eq(div(b, WAD), a)) {
        revert(0, 0)
      }
    }
  }

  /// @notice Casts value to RAY, adding 27 digits of precision.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return b = a * RAY in RAY units.
  function toRay(uint256 a) internal pure returns (uint256 b) {
    assembly ('memory-safe') {
      b := mul(a, RAY)

      // to avoid overflow, b/RAY == a
      if iszero(eq(div(b, RAY), a)) {
        revert(0, 0)
      }
    }
  }

  /// @notice Removes WAD precision from a given value, rounding down.
  /// @return b = a / WAD.
  function fromWadDown(uint256 a) internal pure returns (uint256 b) {
    assembly ('memory-safe') {
      b := div(a, WAD)
    }
  }

  /// @notice Removes RAY precision from a given value, rounding up.
  /// @return b = ceil(a / RAY).
  function fromRayUp(uint256 a) internal pure returns (uint256 b) {
    assembly ('memory-safe') {
      // add 1 if (a % RAY) > 0 to round up the division of a by RAY
      b := add(div(a, RAY), gt(mod(a, RAY), 0))
    }
  }

  /// @notice Converts value from basis points to WAD, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return b = floor(a * WAD / PERCENTAGE_FACTOR) in WAD units.
  function bpsToWad(uint256 a) internal pure returns (uint256 b) {
    return MathUtils.mulDivDown(a, WAD, PERCENTAGE_FACTOR);
  }

  /// @notice Converts value from basis points to RAY, rounding down.
  /// @dev Reverts if intermediate multiplication overflows.
  /// @return b = a * RAY / PERCENTAGE_FACTOR in RAY units.
  function bpsToRay(uint256 a) internal pure returns (uint256) {
    return MathUtils.mulDivDown(a, RAY, PERCENTAGE_FACTOR);
  }
}
