// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
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
        assertGe(sumDebt, assetTotal, INV_HUB_B); // TODO review test case test_replay_2_INV_HUB_B
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
            (uint256 premiumDrawnShares, int256 premiumOffsetRay) = hub.getSpokePremiumData(assetId, spoke);
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
        uint256 convertedAssets = hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId));

        IHub.Asset memory asset = hub.getAsset(assetId);
        uint256 totalDebt = hub.getAssetTotalOwed(assetId);

        // Checks
        assertApproxEqAbs( // TODO review test_replay_3_setUsingAsCollateral
            totalSuppliedAssets,
            convertedAssets,
            hub.previewRemoveByShares(assetId, 1),
            INV_HUB_E
        );

        assertEq(
            totalSuppliedAssets * 1e9,
            asset.liquidity * 1e9 + totalDebt * 1e9 + asset.deficitRay + asset.swept * 1e9,
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

        // TODO take into account the burned interest from virtual shared -> _calculateBurntInterest from Base.t.sol
        // Checks
        assertApproxEqAbs(totalAddedAssets, hub.getAddedAssets(assetId), SPOKE_COUNT, INV_HUB_G);
        assertEq(totalAddedShares, hub.getAddedShares(assetId), INV_HUB_H);
    }

    function assert_INV_HUB_I(uint256 assetId) internal {
        // Get underlying from assetId
        (address underlying,) = hub.getAssetUnderlyingAndDecimals(assetId);

        // Query values
        uint256 liquidity = hub.getAssetLiquidity(assetId);
        uint256 swept = hub.getAssetSwept(assetId);
        uint256 underlyingBalance = IERC20(underlying).balanceOf(address(hub));

        // Checks
        assertGe(underlyingBalance + swept, liquidity, INV_HUB_I);
    }

    function assert_INV_HUB_K(uint256 assetId) internal {
        /// @dev TODO for this check to be meaningful, strategy configuration operations have to be integrated
        IHub.AssetConfig memory assetConfig = hub.getAssetConfig(assetId);

        // Checks
        assertTrue(assetConfig.irStrategy != address(0), INV_HUB_K);
    }

    function assert_INV_HUB_L(uint256 assetId) internal {
        (uint256 premiumShares, int256 premiumOffsetRay) = hub.getAssetPremiumData(assetId);

        assertGe(int256(hub.previewRestoreByShares(assetId, premiumShares) * 1e9), premiumOffsetRay * 1e9, INV_HUB_L);
    }
}
