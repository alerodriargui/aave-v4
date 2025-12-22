// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract InvariantsSpec {
    // TODO: check invariant overlap
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV):
    ///   - Properties that should always hold true in the system.
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         HUB                                               //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_HUB_A2 = "INV_HUB_A2: If hub assets = 0 => shares 0";

    string constant INV_HUB_B =
        "INV_HUB_A: Sum of spoke debts on a single asset must be greater or equal than the total debt of the asset";

    string constant INV_HUB_C =
        "INV_HUB_C: Sum of [baseDrawnShares/premiumDrawnShares/premiumOffsetRay] of individual (spoke/user) should match the corresponding value of the asset on the Hub";

    string constant INV_HUB_E =
        "INV_HUB_E: hub.getTotalSuppliedAssets and hub.getAssetSuppliedAmount should match at any time, should not be off by more than 1 share worth of assets due to division precision loss";

    string constant INV_HUB_F =
        "INV_HUB_E2: hub.getTotalSuppliedAssets = totalAssets() = availableLiquidity + totalDebt + deficit + swept";

    string constant INV_HUB_G =
        "INV_HUB_G: totalAddedAssets = sum of addedAssets of all registered spokes (including present & past treasury spoke)"; // TODO should this be greater or equal?

    string constant INV_HUB_H = "INV_HUB_H: totalAddedShares = sum of addedShares of all registered spokes";

    string constant INV_HUB_I = "INV_HUB_I: asset.underlying.balanceOf(hub) + asset.swept >= asset.liquidity";

    string constant INV_HUB_J =
        "INV_HUB_J: totalDrawn{Shares,Assets} >= any spoke totalDrawn{Shares,Assets} (same for premium debt)"; // TODO implement strict equality on all total == sum type invariants

    string constant INV_HUB_K =
        "INV_HUB_K: Asset.irStrategy should never be address(0) for any (currently/previously) registered asset";

    string constant INV_HUB_L =
        "INV_HUB_L: Asset.premiumShares.toDrawnAssetsUp() * 1e9 >= Asset.premiumOffsetRay * 1e9";

    string constant INV_HUB_M =
        "INV_HUB_M: Liquidity growth (ie accrued interest) >= AccruedFees (even with 100.00% liquidity fee)"; // TODO

    string constant INV_HUB_N =
        "INV_HUB_N: Liquidity growth (ie accrued interest) = AccruedFees + sum of Accrued for all spokes with non zero addedShares"; // TODO

    string constant INV_HUB_O = "INV_HUB_O: sum of deficitRay across spokes for a given asset == total asset deficitRay"; // TODO explore how to track deficitRay for each spoke

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        SPOKE                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant INV_SP_A =
        "INV_SP_A: Spoke reserve accounting should always match hub's spoke accounting on the corresponding registered asset.";

    string constant INV_SP_B =
        "INV_SP_B: User/Reserve cannot have non-zero assets and zero shares in supply or debt sides.";

    string constant INV_SP_C =
        "INV_SP_C: Sum of spoke debts on a single asset must be greater or equal than the total debt of the reserve";

    string constant INV_SP_D = "INV_SP_D: Users without collateral also have no debt.";

    ////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // TODO
    // - Spoke/Asset cannot have non-zero assets and zero shares in add or draw sides.";
    // - 4626 roundtrip on preview methods
}
