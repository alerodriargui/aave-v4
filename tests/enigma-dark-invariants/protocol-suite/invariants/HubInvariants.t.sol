// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {WadRayMath} from "src/libraries/math/WadRayMath.sol";
import "forge-std/console.sol";

// Interfaces
import {IHub} from "src/hub/interfaces/IHub.sol";
import {IERC20} from "src/dependencies/openzeppelin/IERC20.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

/// @title HubInvariants
/// @notice Implements Hub Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract HubInvariants is HandlerAggregator {
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
        // Sum per-spoke values
        uint256 spokeCount = spokesAddresses.length;
        uint256 sumDebt;

        for (uint256 i; i < spokeCount; i++) {
            (uint256 d, uint256 p) = IHub(hubAddress).getSpokeOwed(assetId, spokesAddresses[i]);
            sumDebt += d + p;
        }

        uint256 assetTotal = IHub(hubAddress).getAssetTotalOwed(assetId); // drawn + premium
        assertGe(sumDebt, assetTotal, INV_HUB_B); // TODO review test case test_replay_2_INV_HUB_B
    }

    function assert_INV_HUB_C(address hubAddress, uint256 assetId) internal {
        // Sum per-spoke values
        uint256 spokeCount = spokesAddresses.length;

        uint256 sumDrawnShares;
        uint256 sumPremDrawnShares;
        int256 sumPremOffsetRay;

        for (uint256 i; i < spokeCount; i++) {
            address spoke = spokesAddresses[i];
            sumDrawnShares += IHub(hubAddress).getSpokeDrawnShares(assetId, spoke);
            (uint256 premiumDrawnShares, int256 premiumOffsetRay) = IHub(hubAddress).getSpokePremiumData(assetId, spoke);
            sumPremDrawnShares += premiumDrawnShares;
            sumPremOffsetRay += premiumOffsetRay;
        }

        // Asset totals
        IHub.Asset memory a = IHub(hubAddress).getAsset(assetId);

        // Checks
        assertEq(sumDrawnShares, a.drawnShares, INV_HUB_C);
        assertEq(sumPremDrawnShares, a.premiumShares, INV_HUB_C);
        assertEq(sumPremOffsetRay, a.premiumOffsetRay, INV_HUB_C);
    }

    function assert_INV_HUB_EF(address hubAddress, uint256 assetId) internal {
        // Total amounts
        uint256 totalSuppliedAssets = IHub(hubAddress).getAddedAssets(assetId);
        uint256 convertedAssets =
            IHub(hubAddress).previewRemoveByShares(assetId, IHub(hubAddress).getAddedShares(assetId));

        IHub.Asset memory asset = IHub(hubAddress).getAsset(assetId);
        uint256 totalDebt = IHub(hubAddress).getAssetTotalOwed(assetId);
        uint256 accruedFees = IHub(hubAddress).getAssetAccruedFees(assetId);

        // Checks
        // Note: tolerance increased to 2 shares due to premium rounding accumulation
        assertApproxEqAbs(
            totalSuppliedAssets,
            convertedAssets,
            IHub(hubAddress).previewRemoveByShares(assetId, 1) * 2,
            INV_HUB_E
        );

        // totalAddedAssets + fees = liquidity + totalDebt + deficit + swept
        // Note: uses approx equality due to rounding differences between totalOwed (rounds twice)
        // and aggregatedOwedRay.fromRayUp() (rounds once)
        assertApproxEqAbs(
            (totalSuppliedAssets + accruedFees) * WadRayMath.RAY,
            asset.liquidity * WadRayMath.RAY + totalDebt * WadRayMath.RAY + asset.deficitRay + asset.swept
                * WadRayMath.RAY,
            2 * WadRayMath.RAY, // tolerance of 2 units for rounding
            INV_HUB_F
        );
    }

    function assert_INV_HUB_GH(address hubAddress, uint256 assetId) internal {
        uint256 spokeCount = allSpokes.length;

        // Sum per-spoke values
        uint256 totalAddedAssets;
        uint256 totalAddedShares;
        for (uint256 i; i < spokeCount; i++) {
            totalAddedAssets += IHub(hubAddress).getSpokeAddedAssets(assetId, allSpokes[i]);
            totalAddedShares += IHub(hubAddress).getSpokeAddedShares(assetId, allSpokes[i]);
        }

        // TODO take into account the burned interest from virtual shared -> _calculateBurntInterest from Base.t.sol
        // Checks
        assertApproxEqAbs(totalAddedAssets, IHub(hubAddress).getAddedAssets(assetId), SPOKE_COUNT, INV_HUB_G);
        assertEq(totalAddedShares, IHub(hubAddress).getAddedShares(assetId), INV_HUB_H);
    }

    function assert_INV_HUB_I(address hubAddress, uint256 assetId) internal {
        // Get underlying from assetId
        (address underlying,) = IHub(hubAddress).getAssetUnderlyingAndDecimals(assetId);

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

    function assert_INV_HUB_L(address hubAddress, uint256 assetId) internal {
        (uint256 premiumShares, int256 premiumOffsetRay) = IHub(hubAddress).getAssetPremiumData(assetId);

        assertGe(
            int256(IHub(hubAddress).previewRestoreByShares(assetId, premiumShares) * WadRayMath.RAY),
            premiumOffsetRay,
            INV_HUB_L
        );
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
        (uint256 premiumShares, int256 premiumOffsetRay) = IHub(hubAddress).getAssetPremiumData(assetId);
        uint256 drawnIndex = IHub(hubAddress).getAssetDrawnIndex(assetId);
        assertGe(int256(premiumShares * drawnIndex), premiumOffsetRay, INV_HUB_P);
    }
}
