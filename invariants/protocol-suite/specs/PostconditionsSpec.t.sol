// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title PostconditionsSpec
/// @notice Postcoditions specification for the protocol
/// @dev Contains pseudo code and description for the postcondition properties in the protocol
abstract contract PostconditionsSpec {
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
  /////////////////////////////////////////////////////////////////////////////////////////////////

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

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                        SPOKE                                              //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant GPOST_SP_A =
    "GPOST_SP_A: Stored (user.premiumDrawnShares/user.baseDrawnShares) & calculated user risk premium (calculation based on user's position, via spoke.calculateUserAccountData) need to be the same right after an operation";

  string constant GPOST_SP_B =
    'GPOST_SP_B: Premium debt of an individual user can only decrease by calling repay or liquidationCall when premium debt is not zero';

  string constant GPOST_SP_B2 =
    'GPOST_SP_B2: Drawn debt of an individual user can only decrease by calling repay or liquidationCall and if premium debt is zero after the action';

  string constant HSPOST_SP_C = 'HSPOST_SP_C: User liability should decrease after repayment';

  string constant HSPOST_SP_D = 'HSPOST_SP_D: Unhealthy users cannot borrow more';

  string constant GPOST_SP_E =
    'GPOST_SP_E: DynamicRiskConfiguration for a user position is updated to latest reserve state whenever an action can potentially make their position less healthy';
  // - Updates on: borrow, withdraw, disableAsCollateral.
  // - Unchanged on: supply, repay, liquidate, updateUserRiskPremium, setUserPositionManager.
  // - Enabling collateral updates only the relevant reserve's dynamic config.
  // - Exception: updateUserDynamicConfig explicitly refreshes the user's dynamic config.

  string constant HSPOST_SP_F =
    'HSPOST_SP_F: Total debt of a user should not change after updateUserRiskPremium';

  string constant GPOST_SP_H =
    'GPOST_SP_H: if user totalDebt == 0 and withdraw is called, user can withdraw all supplied';

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                  SPOKE: LIQUIDATION                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  string constant HSPOST_SP_LIQ_A =
    "HSPOST_SP_LIQ_A: Liquidation cannot result in an amount of liquidated debt > user's total debt position";

  string constant HSPOST_SP_LIQ_B =
    "HSPOST_SP_LIQ_B: Liquidation cannot result in an amount of seized collateral (sold collateral + liquidation bonus) > user's collateral position";

  string constant HSPOST_SP_LIQ_C =
    'HSPOST_SP_LIQ_C: Liquidator is always forced to repay all the debt of a user if debt value is below DUST_DEBT_LIQUIDATION_THRESHOLD';

  string constant HSPOST_SP_LIQ_D =
    'HSPOST_SP_LIQ_D: Liquidation cannot result in an amount of liquidated debt > debtToCover';

  string constant HSPOST_SP_LIQ_E = 'HSPOST_SP_LIQ_E: Only unhealthy users can be liquidated';

  string constant HSPOST_SP_LIQ_G =
    'HSPOST_SP_LIQ_G: After liquidation, if debt remains, health factor should improve toward target';

  string constant GPOST_SP_LIQ_G =
    'GPOST_SP_LIQ_G: Only liquidations can deteriorate the health factor of an already unhealthy account';

  string constant GPOST_SP_LIQ_H =
    'GPOST_SP_LIQ_H: Only a supply, repay & liquidationCall can leave an account in an unhealthy state';
}
