// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {InvariantsSpec} from '../../protocol-suite/specs/InvariantsSpec.t.sol';

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract HubInvariantsSpec is InvariantsSpec {
  /////////////////////////////////////////////////////////////////////////////////////////////*/

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         ERC4626                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // Add
  string constant HSPOST_HUB_ERC4626_ADD_A =
    'HSPOST_HUB_ERC4626_ADD_A: After add, spoke addedAssets must increase by at at most addedAmount';

  string constant HSPOST_HUB_ERC4626_ADD_B =
    'HSPOST_HUB_ERC4626_ADD_B: After add, spoke addedShares must increase by addedSharesAmount';

  string constant HSPOST_HUB_ERC4626_ADD_C =
    'HSPOST_HUB_ERC4626_ADD_C: previewAddedShares must be less than or equal to the added shares after the action';

  // Remove
  string constant HSPOST_HUB_ERC4626_REMOVE_A =
    'HSPOST_HUB_ERC4626_REMOVE_A: After remove, spoke addedAssets must decrease by at least removedAmount';

  string constant HSPOST_HUB_ERC4626_REMOVE_B =
    'HSPOST_HUB_ERC4626_REMOVE_B: After remove, spoke addedShares must decrease by removedSharesAmount';

  string constant HSPOST_HUB_ERC4626_REMOVE_C =
    'HSPOST_HUB_ERC4626_REMOVE_C: previewRemovedShares must be greater than or equal to the removed shares after the action';

  // Draw
  string constant HSPOST_HUB_ERC4626_DRAW_A =
    'HSPOST_HUB_ERC4626_DRAW_A: After draw, spoke drawnAssets must increase by at least drawnAmount';

  string constant HSPOST_HUB_ERC4626_DRAW_B =
    'HSPOST_HUB_ERC4626_DRAW_B: After draw, spoke drawnShares must increase by drawnSharesAmount';

  string constant HSPOST_HUB_ERC4626_DRAW_C =
    'HSPOST_HUB_ERC4626_DRAW_C: previewDrawnShares must be greater than or equal to the drawn shares after the action';

  // Restore
  string constant HSPOST_HUB_ERC4626_RESTORE_A =
    'HSPOST_HUB_ERC4626_RESTORE_A: After restore, spoke drawnAssets must increase by at most drawnAmount';

  string constant HSPOST_HUB_ERC4626_RESTORE_B =
    'HSPOST_HUB_ERC4626_RESTORE_B: After restore, spoke drawnShares must decrease by restoredSharesAmount';

  string constant HSPOST_HUB_ERC4626_RESTORE_C =
    'HSPOST_HUB_SP_RESTORE_C: previewRestoredShares must be less than or equal to the restored shares after the action';

  // GENERIC

  string constant INV_HUB_ERC4626_A =
    'INV_HUB_ERC4626_A: Spoke cannot have non-zero assets and zero shares in add side';

  string constant INV_HUB_ERC4626_B =
    'INV_HUB_ERC4626_B: Spoke cannot have non-zero assets and zero shares in draw side';

  string constant INV_HUB_ERC4626_C =
    'INV_HUB_ERC4626_C: Asset cannot have non-zero assets and zero shares in add side';

  string constant INV_HUB_ERC4626_D =
    'INV_HUB_ERC4626_D: Asset cannot have non-zero assets and zero shares in draw side';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         ERC4626 ROUNDTRIP                                 //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant HSPOST_HUB_ERC4626_RT_A =
    'HSPOST_HUB_SP_ERC4626_RT_A: previewRemoveByShares(previewAddByAssets(amount)) <= shares added';

  string constant HSPOST_HUB_ERC4626_RT_B =
    'HSPOST_HUB_SP_ERC4626_RT_B: remove(previewRemoveByShares(add(amount))) >= add(amount)';

  string constant HSPOST_HUB_ERC4626_RT_C =
    'HSPOST_HUB_SP_ERC4626_RT_C: previewAddByAssets(previewRemoveByShares(shares)) >= shares';

  string constant HSPOST_HUB_ERC4626_RT_D =
    'HSPOST_HUB_SP_ERC4626_RT_D: add(previewAddByShares(remove(amount))) <= shares removed';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          HUB: AVAILABILITY                                //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant INV_HUB_AVAILABILITY_A = 'INV_HUB_AVAILABILITY_A: getAddedAssets must not revert';

  string constant INV_HUB_AVAILABILITY_B = 'INV_HUB_AVAILABILITY_B: getAssetOwed must not revert';

  string constant INV_HUB_AVAILABILITY_C =
    'INV_HUB_AVAILABILITY_C: getAssetTotalOwed must not revert';

  string constant INV_HUB_AVAILABILITY_D =
    'INV_HUB_AVAILABILITY_D: getAssetPremiumRay must not revert';

  string constant INV_HUB_AVAILABILITY_E =
    'INV_HUB_AVAILABILITY_E: getAssetAccruedFees must not revert';

  string constant INV_HUB_AVAILABILITY_F =
    'INV_HUB_AVAILABILITY_F: getSpokeAddedAssets must not revert';

  string constant INV_HUB_AVAILABILITY_G = 'INV_HUB_AVAILABILITY_G: getSpokeOwed must not revert';

  string constant INV_HUB_AVAILABILITY_H =
    'INV_HUB_AVAILABILITY_H: getSpokeTotalOwed must not revert';

  string constant INV_HUB_AVAILABILITY_I =
    'INV_HUB_AVAILABILITY_I: getSpokePremiumRay must not revert';
}
