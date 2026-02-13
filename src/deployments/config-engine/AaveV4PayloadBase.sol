// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title AaveV4PayloadBase
/// @author Aave Labs
/// @notice Base contract for all Aave V4 governance payloads.
/// @dev Provides the execute() entry point with pre/post hooks.
///      Subclasses implement _executePayload() with their specific logic.
abstract contract AaveV4PayloadBase {
  /// @notice Executes the payload.
  function execute() external {
    _preExecute();
    _executePayload();
    _postExecute();
  }

  /// @notice Implement payload-specific logic here.
  function _executePayload() internal virtual;

  /// @notice Hook called before the payload execution. Override as needed.
  function _preExecute() internal virtual {}

  /// @notice Hook called after the payload execution. Override as needed.
  function _postExecute() internal virtual {}
}
