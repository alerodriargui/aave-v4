// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HubInvariantsSpec} from '../../hub-suite/specs/HubInvariantsSpec.t.sol';

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains spoke invariant strings. Hub invariant strings are inherited from HubInvariantsSpec.
abstract contract InvariantsSpec is HubInvariantsSpec {
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

  string constant INV_SP_I =
    'INV_SP_I: User cannot have premium shares/offset without drawn shares (premium debt is always repaid first, and can only be created when drawn shares exist)';
}
