// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {Premium} from 'src/hub/libraries/Premium.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
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
  using WadRayMath for *;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HUB                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_HUB_A(address hubAddress, uint256 assetId) internal {
    uint256 assets = IHub(hubAddress).getAddedAssets(assetId);

    if (assets == 0) {
      assertEq(IHub(hubAddress).getAddedShares(assetId), 0, INV_HUB_A2);
    }
  }

  function assert_INV_HUB_B(address hubAddress, uint256 assetId) internal {
    // Sum per-spoke values (use allSpokes to include treasury spokes for consistency with INV_HUB_GH/O)
    uint256 spokeCount = allSpokes.length;
    uint256 sumDebt;

    for (uint256 i; i < spokeCount; i++) {
      sumDebt += IHub(hubAddress).getSpokeTotalOwed(assetId, allSpokes[i]);
    }

    uint256 assetTotal = IHub(hubAddress).getAssetTotalOwed(assetId);
    assertGe(sumDebt, assetTotal, INV_HUB_B);
  }

  function assert_INV_HUB_C(address hubAddress, uint256 assetId) internal {
    // Sum per-spoke values (use allSpokes to include treasury spokes for consistency with INV_HUB_GH/O)
    uint256 spokeCount = allSpokes.length;

    uint256 sumDrawnShares;
    uint256 sumPremDrawnShares;
    int256 sumPremOffsetRay;

    for (uint256 i; i < spokeCount; i++) {
      address spoke = allSpokes[i];
      sumDrawnShares += IHub(hubAddress).getSpokeDrawnShares(assetId, spoke);
      (uint256 premiumDrawnShares, int256 premiumOffsetRay) = IHub(hubAddress).getSpokePremiumData(
        assetId,
        spoke
      );
      sumPremDrawnShares += premiumDrawnShares;
      sumPremOffsetRay += premiumOffsetRay;
    }

    // Asset totals
    AssetVars memory vars = _assetVarsAfter(hubAddress, assetId);

    // Checks
    assertEq(sumDrawnShares, vars.asset.drawnShares, INV_HUB_C);
    assertEq(sumPremDrawnShares, vars.asset.premiumShares, INV_HUB_C);
    assertEq(sumPremOffsetRay, vars.asset.premiumOffsetRay, INV_HUB_C);
  }

  function assert_INV_HUB_E(address hubAddress, uint256 assetId) internal {
    uint256 totalAssets = IHub(hubAddress).getAddedAssets(assetId);
    uint256 totalShares = IHub(hubAddress).getAddedShares(assetId);

    // interest accrued on virtual shares
    uint256 burntInterest = totalAssets -
      IHub(hubAddress).previewRemoveByShares(assetId, totalShares);

    // Checks: totalAddedAssets ≈ previewRemoveByShares(totalAddedShares)
    // Tolerance: the virtual offset (V=1e6) absorbs a fraction of accrued interest when
    // converting all shares back to assets.
    assertApproxEqAbs(
      totalAssets,
      IHub(hubAddress).previewRemoveByShares(assetId, totalShares), // round down
      burntInterest,
      INV_HUB_E_1
    );

    assertGe(
      totalAssets + SharesMath.VIRTUAL_ASSETS,
      IHub(hubAddress).previewRemoveByShares(assetId, totalShares + SharesMath.VIRTUAL_ASSETS),
      INV_HUB_E_2
    );
  }

  function assert_INV_HUB_F(address hubAddress, uint256 assetId) internal {
    uint256 totalAssets = IHub(hubAddress).getAddedAssets(assetId);
    uint256 accruedFees = IHub(hubAddress).getAssetAccruedFees(assetId);

    IHub.Asset memory asset = IHub(hubAddress).getAsset(assetId);
    uint256 drawnIndex = IHub(hubAddress).getAssetDrawnIndex(assetId);

    uint256 premiumRay = Premium.calculatePremiumRay({
      premiumShares: asset.premiumShares,
      premiumOffsetRay: asset.premiumOffsetRay,
      drawnIndex: drawnIndex
    });
    uint256 drawnRay = asset.drawnShares * drawnIndex;
    uint256 aggregatedOwed = (drawnRay + premiumRay + asset.deficitRay).fromRayUp();

    assertEq(totalAssets + accruedFees, asset.liquidity + aggregatedOwed + asset.swept, INV_HUB_F);
  }

  function assert_INV_HUB_GH(address hubAddress, uint256 assetId) internal {
    uint256 spokeCount = allSpokes.length;
    uint256 tolerancePerActor = IHub(hubAddress).previewAddByShares(assetId, 1);

    // Sum per-spoke values
    uint256 totalAddedAssets;
    uint256 totalAddedShares;
    for (uint256 i; i < spokeCount; i++) {
      totalAddedAssets += IHub(hubAddress).getSpokeAddedAssets(assetId, allSpokes[i]);
      totalAddedShares += IHub(hubAddress).getSpokeAddedShares(assetId, allSpokes[i]);
    }

    totalAddedAssets += _calculateBurntInterest(IHub(hubAddress), assetId);

    // Checks
    assertApproxEqAbs(
      totalAddedAssets,
      IHub(hubAddress).getAddedAssets(assetId),
      (spokeCount + 2) * tolerancePerActor,
      INV_HUB_G
    );
    assertEq(totalAddedShares, IHub(hubAddress).getAddedShares(assetId), INV_HUB_H);
  }

  function assert_INV_HUB_I(address hubAddress, uint256 assetId) internal {
    // Get underlying from assetId
    (address underlying, ) = IHub(hubAddress).getAssetUnderlyingAndDecimals(assetId);

    // Query values
    uint256 liquidity = IHub(hubAddress).getAssetLiquidity(assetId);
    uint256 swept = IHub(hubAddress).getAssetSwept(assetId);
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(IHub(hubAddress)));

    // Checks
    assertGe(underlyingBalance + swept, liquidity, INV_HUB_I);
  }

  function assert_INV_HUB_K(address hubAddress, uint256 assetId) internal {
    /// @dev TODO for this check to be meaningful, strategy configuration operations have to be integrated
    IHub.AssetConfig memory assetConfig = IHub(hubAddress).getAssetConfig(assetId);

    // Checks
    assertTrue(assetConfig.irStrategy != address(0), INV_HUB_K);
  }

  function assert_INV_HUB_O(address hubAddress, uint256 assetId) internal {
    uint256 spokeCount = allSpokes.length;
    uint256 totalDeficitRay;
    for (uint256 i; i < spokeCount; i++) {
      totalDeficitRay += IHub(hubAddress).getSpokeDeficitRay(assetId, allSpokes[i]);
    }
    assertEq(totalDeficitRay, IHub(hubAddress).getAssetDeficitRay(assetId), INV_HUB_O);
  }

  function assert_INV_HUB_P(address hubAddress, uint256 assetId) internal {
    (uint256 premiumShares, int256 premiumOffsetRay) = IHub(hubAddress).getAssetPremiumData(
      assetId
    );
    uint256 drawnIndex = IHub(hubAddress).getAssetDrawnIndex(assetId);
    assertGe(int256(premiumShares * drawnIndex), premiumOffsetRay, INV_HUB_P);
  }

  function assert_INV_HUB_Q(address hubAddress, uint256 assetId) internal {
    uint256 currentIndex = IHub(hubAddress).getAssetDrawnIndex(assetId);
    if (lastSeenDrawnIndex[hubAddress][assetId] > 0) {
      assertGe(currentIndex, lastSeenDrawnIndex[hubAddress][assetId], INV_HUB_Q);
    }
    lastSeenDrawnIndex[hubAddress][assetId] = currentIndex;
  }

  function assert_INV_HUB_R(address hubAddress, uint256 assetId) internal {
    uint256 assets = IHub(hubAddress).getAddedAssets(assetId) + 1e6;
    uint256 shares = IHub(hubAddress).getAddedShares(assetId) + 1e6;
    if (lastSeenShares[hubAddress][assetId] > 0) {
      // assets/shares >= lastAssets/lastShares  <=>  assets * lastShares >= lastAssets * shares
      assertFullMulGe(
        assets,
        lastSeenShares[hubAddress][assetId],
        lastSeenAssets[hubAddress][assetId],
        shares,
        INV_HUB_R
      );
    }
    lastSeenAssets[hubAddress][assetId] = assets;
    lastSeenShares[hubAddress][assetId] = shares;
  }
}
