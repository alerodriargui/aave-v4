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
        "GPOST_HUB_A: Drawn index cannot decrease (remains constant or increases). If no time passes, it stays constant. only increases due to interest accumulation";

    string constant GPOST_HUB_B =
        "GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases). If no time passes, it stays constant. it increases due to interest accumulation, premium debt settlement and donations (from actions' rounding).";

    string constant GPOST_HUB_C =
        "GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block.";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                        SPOKE                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant GPOST_SP_A =
        "GPOST_SP_A: Stored (user.premiumDrawnShares/user.baseDrawnShares) & calculated user risk premium (calculation based on user's position, via spoke.calculateUserAccountData) need to be the same right after an operation";

    string constant GPOST_SP_B =
        "GPOST_SP_B: Premium debt of an individual user, spoke can only decrease by calling repay when premium debt is not zero";// TODO add liquidationCall to the condition

    string constant HSPOST_SP_C = "HSPOST_SP_C: User liability should decrease after repayment";

    string constant HSPOST_SP_D = "HSPOST_SP_D: Unhealthy users cannot borrow more";

    string constant GPOST_SP_E =
        "GPOST_SP_E: DynamicRiskConfiguration for a user position is updated to latest reserve state whenever an action can potentially make their position less healthy";
    // - Updates on: borrow, withdraw, disableAsCollateral.
    // - Unchanged on: supply, repay, liquidate, updateUserRiskPremium, setUserPositionManager.
    // - Enabling collateral updates only the relevant reserve's dynamic config.
    // - Exception: updateUserDynamicConfig explicitly refreshes the user's dynamic config.

    string constant HSPOST_SP_F = "HSPOST_SP_F: Total debt of a user should not change after updateUserRiskPremium";

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                  SPOKE: LIQUIDATION                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    string constant HSPOST_SP_LIQ_A =
        "HSPOST_SP_LIQ_A: Liquidation cannot result in an amount of liquidated debt > user's total debt position";

    string constant HSPOST_SP_LIQ_B =
        "HSPOST_SP_LIQ_B: Liquidation cannot result in an amount of seized collateral (sold collateral + liquidation bonus) > user's collateral position"; // TODO

    string constant HSPOST_SP_LIQ_C =
        "HSPOST_SP_LIQ_C: Liquidator is always forced to repay all the debt of a user if debt value is below DUST_DEBT_LIQUIDATION_THRESHOLD";

    string constant HSPOST_SP_LIQ_D =
        "HSPOST_SP_LIQ_D: Liquidation cannot result in an amount of liquidated debt > debtToCover";
}
