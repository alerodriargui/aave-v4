// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

interface ISupplyRepayPositionManager is IPositionManagerBase {
  /// @notice Executes a supply on behalf of a user.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to supply.
  /// @param onBehalfOf The address of the user to supply on behalf of.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Executes a repay on behalf of a user.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to repay.
  /// @param onBehalfOf The address of the user to repay on behalf of.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);
}
