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

  string constant INV_HUB_A2 = 'INV_HUB_A2: If hub assets = 0 => shares 0';

  string constant INV_HUB_B =
    'INV_HUB_B: Sum of spoke debts on a single asset must be greater or equal than the total debt of the asset';

  string constant INV_HUB_C =
    'INV_HUB_C: Sum of [baseDrawnShares/premiumDrawnShares/premiumOffsetRay] of individual (spoke/user) should match the corresponding value of the asset on the Hub';

  string constant INV_HUB_E_1 =
    'INV_HUB_E: total assets is equal to or greater than the supplied amount without taking into account the virtual assets and shares up to the burn interest to virtual shares';

  string constant INV_HUB_E_2 =
    'INV_HUB_E: total assets is equal to the supplied amount when taking into account the virtual assets and shares';

  string constant INV_HUB_F =
    'INV_HUB_F: hub.getTotalSuppliedAssets = totalAssets() = availableLiquidity + (totalDebtRay + deficitRay).fromRayUp + swept';

  string constant INV_HUB_G =
    'INV_HUB_G: totalAddedAssets = sum of addedAssets of all registered spokes (including present & past treasury spoke) with a tolerance of SPOKE_COUNT'; // TODO check if tolerance is correct

  string constant INV_HUB_H =
    'INV_HUB_H: totalAddedShares = sum of addedShares of all registered spokes';

  string constant INV_HUB_I =
    'INV_HUB_I: asset.underlying.balanceOf(hub) + asset.swept >= asset.liquidity';

  string constant INV_HUB_K =
    'INV_HUB_K: Asset.irStrategy should never be address(0) for any (currently/previously) registered asset';

  string constant INV_HUB_O =
    'INV_HUB_O: sum of deficitRay across spokes for a given asset == total asset deficitRay';

  string constant INV_HUB_P =
    'INV_HUB_P: Premium offset should not exceed premium shares * drawnIndex';

  string constant INV_HUB_Q =
    'INV_HUB_Q: Drawn index must be monotonically non-decreasing across invariant checks';

  string constant INV_HUB_R =
    'INV_HUB_R: Supply share price (addedAssets/addedShares) must be monotonically non-decreasing across invariant checks';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        SPOKE                                              //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_SP_A =
    "INV_SP_A: Spoke reserve accounting should always match hub's spoke accounting on the corresponding registered asset.";

  string constant INV_SP_B =
    'INV_SP_B: User/Reserve cannot have non-zero assets and zero shares in supply or debt sides.';

  string constant INV_SP_C =
    'INV_SP_C: Sum of spoke debts on a single asset must be greater or equal than the total debt of the reserve';

  string constant INV_SP_D = 'INV_SP_D: Users without collateral also have no debt.';

  string constant INV_SP_E =
    'INV_SP_E: Sum of user supplied shares on a spoke for a given asset == spoke supplied shares (hub spoke added shares)';

  string constant INV_SP_F =
    'INV_SP_F: Sum of user supplied assets on a spoke for a given asset == spoke supplied assets (hub spoke added assets)';

  string constant INV_SP_H =
    'INV_SP_H: User dynamicConfigKey must never exceed the reserve dynamicConfigKey (no future config reference)';
}
