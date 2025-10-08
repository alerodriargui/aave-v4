// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IHub} from "src/hub/interfaces/IHub.sol";
import {IERC20} from "src/dependencies/openzeppelin/IERC20.sol";

// Contracts
import {HandlerAggregator} from "../HandlerAggregator.t.sol";

import "forge-std/console.sol";

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
        uint256 spokeCount = spokesAddresses.length;
        uint256 sumDebt;

        for (uint256 i; i < spokeCount; i++) {
            (uint256 d, uint256 p) = hub.getSpokeOwed(assetId, spokesAddresses[i]);
            sumDebt += d + p;
        }

        uint256 assetTotal = hub.getAssetTotalOwed(assetId); // drawn + premium
        assertGe(sumDebt, assetTotal, INV_HUB_B);
    }

    function assert_INV_HUB_C(uint256 assetId) internal {
        // Sum per-spoke values
        uint256 spokeCount = spokesAddresses.length;

        uint256 sumDrawnShares;
        uint256 sumPremDrawnShares;
        uint256 sumPremOffset;
        uint256 sumPremRealized;

        for (uint256 i; i < spokeCount; i++) {
            address spoke = spokesAddresses[i];
            sumDrawnShares += hub.getSpokeDrawnShares(assetId, spoke);
            (uint256 premiumDrawnShares, uint256 premiumOffset, uint256 realizedPremium) =
                hub.getSpokePremiumData(assetId, spoke);
            sumPremDrawnShares += premiumDrawnShares;
            sumPremOffset += premiumOffset;
            sumPremRealized += realizedPremium;
        }

        // Asset totals
        IHub.Asset memory a = hub.getAsset(assetId);

        // Checks
        assertEq(sumDrawnShares, a.drawnShares, INV_HUB_C);
        assertEq(sumPremDrawnShares, a.premiumShares, INV_HUB_C);
        assertEq(sumPremOffset, a.premiumOffset, INV_HUB_C);
        assertEq(sumPremRealized, a.realizedPremium, INV_HUB_C);
    }

    function assert_INV_HUB_EF(uint256 assetId) internal {
        // Total amounts
        uint256 totalSuppliedAssets = hub.getAddedAssets(assetId);
        uint256 convertedAssets = hub.previewRemoveByShares(assetId, hub.getAddedShares(assetId));

        IHub.Asset memory asset = hub.getAsset(assetId);
        uint256 totalDebt = hub.getAssetTotalOwed(assetId);

        // Checks
        //assertEq(totalSuppliedAssets, convertedAssets, INV_HUB_E); TODO review this invariant test_replay_invariant_INV_HUB_E
        assertEq(totalSuppliedAssets, asset.liquidity + totalDebt + asset.deficit + asset.swept, INV_HUB_F);
    }

    function assert_INV_HUB_GH(uint256 assetId) internal {
        uint256 spokeCount = spokesAddresses.length;

        // Sum per-spoke values
        uint256 totalAddedAssets;
        uint256 totalAddedShares;
        for (uint256 i; i < spokeCount; i++) {
            totalAddedAssets += hub.getSpokeAddedAssets(assetId, spokesAddresses[i]);
            totalAddedShares += hub.getSpokeAddedShares(assetId, spokesAddresses[i]);
        }

        // Checks
        assertEq(totalAddedAssets, hub.getAddedAssets(assetId), INV_HUB_G);
        assertEq(totalAddedShares, hub.getAddedShares(assetId), INV_HUB_H);
    }

    function assert_INV_HUB_I(uint256 assetId, address underlying) internal {
        // Query values
        uint256 liquidity = hub.getLiquidity(assetId);
        uint256 swept = hub.getSwept(assetId);
        uint256 underlyingBalance = IERC20(underlying).balanceOf(address(hub));

        // Checks
        assertEq(underlyingBalance + swept, liquidity, INV_HUB_I);
    }

    function assert_INV_HUB_K(uint256 assetId) internal {
        // TODO for this check to be meaningful, strategy configuration operations have to be integrated
        IHub.AssetConfig memory assetConfig = hub.getAssetConfig(assetId);

        // Checks
        assertTrue(assetConfig.irStrategy != address(0), INV_HUB_K);
    }

    function assert_INV_HUB_L(uint256 assetId) internal {
        (uint256 premiumShares, uint256 premiumOffset,) = hub.getAssetPremiumData(assetId);

        assertGe(hub.previewRestoreByShares(assetId, premiumShares), premiumOffset, INV_HUB_L);
    }
}
