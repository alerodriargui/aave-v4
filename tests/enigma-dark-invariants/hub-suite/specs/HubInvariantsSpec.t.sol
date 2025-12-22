// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {InvariantsSpec} from "../../protocol-suite/specs/InvariantsSpec.t.sol";

/// @title InvariantsSpec
/// @notice Invariants specification for the protocol
/// @dev Contains pseudo code and description for the invariant properties in the protocol
abstract contract HubInvariantsSpec is InvariantsSpec {
    /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - INVARIANTS (INV):
    ///   - Properties that should always hold true in the system.
    ///   - Implemented in the /invariants folder.

    /////////////////////////////////////////////////////////////////////////////////////////////*/
    ///////////////////////////////////////////////////////////////////////////////////////////////
    // TODO
    // - Spoke/Asset cannot have non-zero assets and zero shares in add or draw sides.";
    // - 4626 roundtrip on preview methods

    }
