// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
        assertGe(sumDebt, assetTotal, INV_HUB_B);
    }

    function assert_INV_HUB_C(address hubAddress, uint256 assetId) internal {
        // Sum per-spoke values
        uint256 spokeCount = spokesAddresses.length;

        uint256 sumDrawnShares;
        uint256 sumPremDrawnShares;
        uint256 sumPremOffset;
        uint256 sumPremRealized;

        for (uint256 i; i < spokeCount; i++) {
            address spoke = spokesAddresses[i];
            sumDrawnShares += IHub(hubAddress).getSpokeDrawnShares(assetId, spoke);
            (uint256 premiumDrawnShares, uint256 premiumOffset, uint256 realizedPremium) =
                IHub(hubAddress).getSpokePremiumData(assetId, spoke);
            sumPremDrawnShares += premiumDrawnShares;
            sumPremOffset += premiumOffset;
            sumPremRealized += realizedPremium;
        }

        // Asset totals
        IHub.Asset memory a = IHub(hubAddress).getAsset(assetId);

        // Checks
        assertEq(sumDrawnShares, a.drawnShares, INV_HUB_C);
        assertEq(sumPremDrawnShares, a.premiumShares, INV_HUB_C);
        assertEq(sumPremOffset, a.premiumOffset, INV_HUB_C);
        assertEq(sumPremRealized, a.realizedPremium, INV_HUB_C);
    }

    function assert_INV_HUB_EF(address hubAddress, uint256 assetId) internal {
        // Total amounts
        uint256 totalSuppliedAssets = IHub(hubAddress).getAddedAssets(assetId);
        uint256 convertedAssets =
            IHub(hubAddress).previewRemoveByShares(assetId, IHub(hubAddress).getAddedShares(assetId));

        IHub.Asset memory asset = IHub(hubAddress).getAsset(assetId);
        uint256 totalDebt = IHub(hubAddress).getAssetTotalOwed(assetId);

        // Checks
        //assertEq(totalSuppliedAssets, convertedAssets, INV_HUB_E); TODO review this invariant test_replay_invariant_INV_HUB_E
        assertEq(totalSuppliedAssets, asset.liquidity + totalDebt + asset.deficit + asset.swept, INV_HUB_F);
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
        // Checks
        //assertApproxEqAbs(totalAddedAssets, IHub(hubAddress).getAddedAssets(assetId), SPOKE_COUNT, INV_HUB_G); TODO remove comment after going over test_replay_12_donateUnderlyingToSpoke
        assertEq(totalAddedShares, IHub(hubAddress).getAddedShares(assetId), INV_HUB_H);
    }

    function assert_INV_HUB_I(address hubAddress, uint256 assetId, address underlying) internal {
        // Query values
        uint256 liquidity = IHub(hubAddress).getLiquidity(assetId);
        uint256 swept = IHub(hubAddress).getSwept(assetId);
        uint256 underlyingBalance = IERC20(underlying).balanceOf(address(IHub(hubAddress)));

        // Checks
        assertGe(underlyingBalance + swept, liquidity, INV_HUB_I);
    }

    function assert_INV_HUB_K(address hubAddress, uint256 assetId) internal {
        // TODO for this check to be meaningful, strategy configuration operations have to be integrated
        IHub.AssetConfig memory assetConfig = IHub(hubAddress).getAssetConfig(assetId);

        // Checks
        assertTrue(assetConfig.irStrategy != address(0), INV_HUB_K);
    }

    function assert_INV_HUB_L(address hubAddress, uint256 assetId) internal {
        (uint256 premiumShares, uint256 premiumOffset,) = IHub(hubAddress).getAssetPremiumData(assetId);

        assertGe(IHub(hubAddress).previewRestoreByShares(assetId, premiumShares), premiumOffset, INV_HUB_L);
    }
}
