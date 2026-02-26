// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title EngineFlags
/// @author Aave Labs
/// @notice Sentinel values for partial updates in config engine structs.
library EngineFlags {
  /// @dev Thrown when toBool receives a value other than 0 or 1.
  error InvalidBoolValue(uint256 value);

  /// @dev Sentinel value meaning "do not update this field".
  uint256 internal constant KEEP_CURRENT = type(uint256).max;
  /// @dev Sentinel address meaning "do not update this address field".
  address internal constant KEEP_CURRENT_ADDRESS = address(type(uint160).max);

  /// @dev Convenience constant representing an enabled boolean flag (1).
  uint256 internal constant ENABLED = 1;
  /// @dev Convenience constant representing a disabled boolean flag (0).
  uint256 internal constant DISABLED = 0;

  /// @notice Converts a uint256 flag (0 or 1) to a bool. Reverts on any other value.
  /// @param flag The uint256 flag to convert (must be 0 or 1).
  /// @return The boolean representation of the flag.
  function toBool(uint256 flag) internal pure returns (bool) {
    require(flag == 0 || flag == 1, InvalidBoolValue(flag));
    return flag == 1;
  }

  /// @notice Converts a bool to uint256 (false = DISABLED, true = ENABLED).
  /// @param value The bool value to convert.
  /// @return The uint256 representation of the value.
  function fromBool(bool value) internal pure returns (uint256) {
    return value ? ENABLED : DISABLED;
  }
}
