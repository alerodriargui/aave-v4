// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title HubPostconditionsSpec
/// @notice Postconditions specification for the hub
/// @dev Contains pseudo code and description for the postcondition properties in the hub.
///      This is the canonical source for all hub postcondition strings.
///      Protocol-suite imports these via inheritance.
abstract contract HubPostconditionsSpec {
  /*/////////////////////////////////////////////////////////////////////////////////////////////
    //                                      PROPERTY TYPES                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// - POSTCONDITIONS:
    ///   - Properties that should hold true after an action is executed.
    ///   - Implemented in the /hooks and /handlers folders.
    ///   - There are two types of POSTCONDITIONS:
    ///     - GLOBAL POSTCONDITIONS (GPOST):
    ///       - Properties that should always hold true after any action is executed.
    ///       - Checked in the `_checkPostConditions` function within the HookAggregator contract.
    ///     - HANDLER-SPECIFIC POSTCONDITIONS (HSPOST):
    ///       - Properties that should hold true after a specific action is executed in a specific context.
    ///       - Implemented within each handler function, under the HANDLER-SPECIFIC POSTCONDITIONS section.

    /////////////////////////////////////////////////////////////////////////////////////////////*/

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         HUB                                               //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_HUB_A =
    'GPOST_HUB_A: Drawn index cannot decrease (remains constant or increases). If no time passes, it stays constant. only increases due to interest accumulation';

  string constant GPOST_HUB_B =
    "GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases). If no time passes, it stays constant. it increases due to interest accumulation, premium debt settlement and donations (from actions' rounding).";

  string constant GPOST_HUB_C =
    'GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block.';

  string constant GPOST_HUB_D =
    'GPOST_HUB_D: lastUpdateTimestamp must be <= block.timestamp after any action (timestamps cannot be in the future).';

  string constant GPOST_HUB_E =
    'GPOST_HUB_E: if addedAssets for a spoke & assetId increase, addedAssets <= addCap * precision (when cap != MAX)';

  string constant GPOST_HUB_F =
    'GPOST_HUB_F: if owed for a spoke & assetId increase, owed <= drawCap * precision (when cap != MAX)'; // TODO-ok take into account the deficit, use Owed instead of drawn -> review fix

  string constant GPOST_HUB_G =
    'GPOST_HUB_G: lastUpdateTimestamp is monotonic non-decreasing across actions (time does not go backwards)';

  string constant HSPOST_HUB_M =
    'HSPOST_HUB_M: refreshPremium cannot change total premium debt (only redistribution)';
}
