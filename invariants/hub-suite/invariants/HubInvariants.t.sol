// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

// Contracts
import {HandlerAggregator} from '../HandlerAggregator.t.sol';

/// @title HubInvariants
/// @notice Implements Hub Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract HubInvariants is HandlerAggregator {
  using SafeCast for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HUB                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  function assert_INV_HUB_A(uint256 assetId) internal {
    uint256 assets = hub.getAddedAssets(assetId);

    if (assets == 0) {
      assertEq(hub.getAddedShares(assetId), 0, INV_HUB_A2);
    }
  }

  function assert_INV_HUB_B(uint256 assetId) internal {
    // Sum per-spoke values
    uint256 spokeCount = NUMBER_OF_ACTORS;
    uint256 sumDebt;

    for (uint256 i; i < spokeCount; i++) {
      (uint256 d, uint256 p) = hub.getSpokeOwed(assetId, actorAddresses[i]);
      sumDebt += d + p;
    }

    uint256 assetTotal = hub.getAssetTotalOwed(assetId); // drawn + premium
    assertGe(sumDebt, assetTotal, INV_HUB_B);
  }

  function assert_INV_HUB_C(uint256 assetId) internal {
    // Sum per-spoke values
    uint256 spokeCount = NUMBER_OF_ACTORS;

    uint256 sumDrawnShares;
    uint256 sumPremDrawnShares;
    int256 sumPremOffsetRay;

    for (uint256 i; i < spokeCount; i++) {
      address spoke = actorAddresses[i];
      sumDrawnShares += hub.getSpokeDrawnShares(assetId, spoke);
      (uint256 premiumDrawnShares, int256 premiumOffsetRay) = hub.getSpokePremiumData(
        assetId,
        spoke
      );
      sumPremDrawnShares += premiumDrawnShares;
      sumPremOffsetRay += premiumOffsetRay;
    }

    // Asset totals
    IHub.Asset memory a = hub.getAsset(assetId);

    // Checks
    assertEq(sumDrawnShares, a.drawnShares, INV_HUB_C);
    assertEq(sumPremDrawnShares, a.premiumShares, INV_HUB_C);
    assertEq(sumPremOffsetRay, a.premiumOffsetRay, INV_HUB_C);
  }

  function assert_INV_HUB_EF(uint256 assetId) internal {
    // Total amounts
    uint256 totalSuppliedAssets = hub.getAddedAssets(assetId);

    IHub.Asset memory asset = hub.getAsset(assetId);
    uint256 totalDebt = hub.getAssetTotalOwed(assetId);

    // Checks
    assertApproxEqAbs(
      //TODO check todo file INV_HUB_E
      totalSuppliedAssets,
      hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId)),
      hub.previewRemoveByShares(assetId, 1), // tolerance of 1 share for rounding
      INV_HUB_E
    );

    assertEq(
      totalSuppliedAssets * WadRayMath.RAY,
      asset.liquidity * WadRayMath.RAY +
        totalDebt * WadRayMath.RAY +
        asset.deficitRay +
        asset.swept * WadRayMath.RAY,
      INV_HUB_F
    );
  }

  function assert_INV_HUB_GH(uint256 assetId) internal {
    uint256 spokeCount = NUMBER_OF_ACTORS;

    // Sum per-spoke values
    uint256 totalAddedAssets;
    uint256 totalAddedShares;
    for (uint256 i; i < spokeCount; i++) {
      totalAddedAssets += hub.getSpokeAddedAssets(assetId, actorAddresses[i]);
      totalAddedShares += hub.getSpokeAddedShares(assetId, actorAddresses[i]);
    }
    totalAddedAssets += hub.getSpokeAddedAssets(assetId, address(this));
    totalAddedShares += hub.getSpokeAddedShares(assetId, address(this));

    // Checks
    uint256 addedShares = hub.getAddedShares(assetId);
    if (addedShares > 0) {
      assertApproxEqAbs(totalAddedAssets, hub.getAddedAssets(assetId), SPOKE_COUNT, INV_HUB_G); // TODO check if tolerance is correct
    }
    assertEq(totalAddedShares, hub.getAddedShares(assetId), INV_HUB_H);
  }

  function assert_INV_HUB_I(uint256 assetId) internal {
    // Get underlying from assetId
    (address underlying, ) = hub.getAssetUnderlyingAndDecimals(assetId);

    // Query values
    uint256 liquidity = hub.getAssetLiquidity(assetId);
    uint256 swept = hub.getAssetSwept(assetId);
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(hub));

    // Checks
    assertGe(underlyingBalance + swept, liquidity, INV_HUB_I);
  }

  function assert_INV_HUB_K(uint256 assetId) internal {
    /// @dev for this check to be meaningful, strategy configuration operations have to be integrated
    IHub.AssetConfig memory assetConfig = hub.getAssetConfig(assetId);

    // Checks
    assertTrue(assetConfig.irStrategy != address(0), INV_HUB_K);
  }

  function assert_INV_HUB_O(uint256 assetId) internal {
    uint256 spokeCount = NUMBER_OF_ACTORS;
    uint256 totalDeficitRay;
    for (uint256 i; i < spokeCount; i++) {
      totalDeficitRay += hub.getSpokeDeficitRay(assetId, actorAddresses[i]);
    }
    assertEq(totalDeficitRay, hub.getAssetDeficitRay(assetId), INV_HUB_O);
  }

  function assert_INV_HUB_P(uint256 assetId) internal {
    (uint256 premiumShares, int256 premiumOffsetRay) = hub.getAssetPremiumData(assetId);
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);
    assertGe((premiumShares * drawnIndex).toInt256(), premiumOffsetRay, INV_HUB_P);
  }

  function assert_INV_HUB_N(uint256 assetId) internal {
    IHub.Asset memory asset = hub.getAsset(assetId);

    // Skip if no debt (no interest can accrue)
    if (asset.drawnShares == 0 && asset.premiumShares == 0) return;

    // Get current index (includes unrealized interest) vs stored index
    uint256 currentIndex = hub.getAssetDrawnIndex(assetId);
    uint256 storedIndex = asset.drawnIndex;

    // Skip if no index growth (no interest accrued)
    if (currentIndex == storedIndex) return;

    // Calculate accrued interest from index growth
    uint256 indexGrowth = currentIndex - storedIndex;
    uint256 totalDebtShares = uint256(asset.drawnShares) + uint256(asset.premiumShares);
    uint256 accruedInterestRay = (totalDebtShares * indexGrowth);

    // Get unrealized fees
    uint256 unrealizedFees = hub.getAssetAccruedFees(assetId) - asset.realizedFees;

    // Invariant: fees × PERCENTAGE_FACTOR × RAY ≈ accruedInterestRay × liquidityFee
    uint256 lhs = unrealizedFees * PercentageMath.PERCENTAGE_FACTOR * WadRayMath.RAY;
    uint256 rhs = accruedInterestRay * asset.liquidityFee;

    // Tolerance: 1 wei rounding scaled up
    uint256 tolerance = WadRayMath.RAY * PercentageMath.PERCENTAGE_FACTOR;
    assertApproxEqAbs(lhs, rhs, tolerance, INV_HUB_N);
  }

  function assert_INV_HUB_ERC4626_A(uint256 assetId, address spoke) internal {
    uint256 addedAssets = hub.getSpokeAddedAssets(assetId, spoke);
    uint256 addedShares = hub.getSpokeAddedShares(assetId, spoke);
    if (addedAssets != 0) assertTrue(addedShares != 0, INV_HUB_ERC4626_A);
  }

  function assert_INV_HUB_ERC4626_B(uint256 assetId, address spoke) internal {
    (uint256 drawnAssets, ) = hub.getSpokeOwed(assetId, spoke);
    uint256 drawnShares = hub.getSpokeDrawnShares(assetId, spoke);
    if (drawnAssets != 0) assertTrue(drawnShares != 0, INV_HUB_ERC4626_B);
  }

  function assert_INV_HUB_ERC4626_C(uint256 assetId) internal {
    uint256 addedAssets = hub.getAddedAssets(assetId);
    uint256 addedShares = hub.getAddedShares(assetId);
    if (addedAssets != 0) assertTrue(addedShares != 0, INV_HUB_ERC4626_C);
  }

  function assert_INV_HUB_ERC4626_D(uint256 assetId) internal {
    (uint256 drawnAssets, ) = hub.getAssetOwed(assetId);
    uint256 drawnShares = hub.getAssetDrawnShares(assetId);
    if (drawnAssets != 0) assertTrue(drawnShares != 0, INV_HUB_ERC4626_D);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     HUB: AVAILABILITY                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_HUB_AVAILABILITY_A(uint256 assetId) internal {
    try hub.getAddedAssets(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_A);
    }
  }

  function assert_INV_HUB_AVAILABILITY_B(uint256 assetId) internal {
    try hub.getAssetOwed(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_B);
    }
  }

  function assert_INV_HUB_AVAILABILITY_C(uint256 assetId) internal {
    try hub.getAssetTotalOwed(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_C);
    }
  }

  function assert_INV_HUB_AVAILABILITY_D(uint256 assetId) internal {
    try hub.getAssetPremiumRay(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_D);
    }
  }

  function assert_INV_HUB_AVAILABILITY_E(uint256 assetId) internal {
    try hub.getAssetAccruedFees(assetId) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_E);
    }
  }

  function assert_INV_HUB_AVAILABILITY_F(uint256 assetId, address spoke) internal {
    try hub.getSpokeAddedAssets(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_F);
    }
  }

  function assert_INV_HUB_AVAILABILITY_G(uint256 assetId, address spoke) internal {
    try hub.getSpokeOwed(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_G);
    }
  }

  function assert_INV_HUB_AVAILABILITY_H(uint256 assetId, address spoke) internal {
    try hub.getSpokeTotalOwed(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_H);
    }
  }

  function assert_INV_HUB_AVAILABILITY_I(uint256 assetId, address spoke) internal {
    try hub.getSpokePremiumRay(assetId, spoke) {} catch {
      assertTrue(false, INV_HUB_AVAILABILITY_I);
    }
  }
}
