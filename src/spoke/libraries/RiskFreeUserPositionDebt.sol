// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title RiskFree User Debt library
/// @author Aave Labs
/// @notice Implements simplified debt calculations for user positions without premium.
library RiskFreeUserPositionDebt {
  using WadRayMath for uint256;
  using MathUtils for uint256;

  /// @notice Returns the user's drawn debt with no premium.
  /// @param userPosition The user position.
  /// @param hub The hub contract.
  /// @param assetId The asset identifier.
  /// @return drawnDebt The user's drawn debt, expressed in asset units.
  /// @return premiumDebtRay Always returns 0 (no premium in risk-free spoke).
  function getDebt(
    ISpoke.UserPosition storage userPosition,
    IHubBase hub,
    uint256 assetId
  ) internal view returns (uint256, uint256) {
    return getDebt(userPosition, hub.getAssetDrawnIndex(assetId));
  }

  /// @notice Returns the user's drawn debt with no premium.
  /// @param userPosition The user position.
  /// @param drawnIndex The current drawn index.
  /// @return drawnDebt The user's drawn debt, expressed in asset units.
  /// @return premiumDebtRay Always returns 0 (no premium in risk-free spoke).
  function getDebt(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnIndex
  ) internal view returns (uint256, uint256) {
    return (uint256(userPosition.drawnShares).rayMulUp(drawnIndex), 0);
  }

  /// @notice Calculates the restore amount - all goes to drawn debt, no premium.
  /// @param userPosition The user position.
  /// @param drawnIndex The drawn index of the reserve.
  /// @param amount The amount to restore.
  /// @return drawnDebtRestored The amount of drawn debt to restore, expressed in asset units.
  /// @return premiumDebtRayRestored Always returns 0 (no premium in risk-free spoke).
  function calculateRestoreAmount(
    ISpoke.UserPosition storage userPosition,
    uint256 drawnIndex,
    uint256 amount
  ) internal view returns (uint256, uint256) {
    uint256 drawnDebt = uint256(userPosition.drawnShares).rayMulUp(drawnIndex);
    uint256 drawnDebtRestored = amount.min(drawnDebt);
    return (drawnDebtRestored, 0);
  }
}
