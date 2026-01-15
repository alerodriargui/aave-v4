// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Hook Contracts
import {DefaultBeforeAfterHooks} from "./DefaultBeforeAfterHooks.t.sol";

// Utils
import {ErrorHandlers} from "../../shared/utils/ErrorHandlers.sol";
import "forge-std/console.sol";

/// @title HookAggregator
/// @notice Helper contract to aggregate all before / after hook contracts, inherited on each handler
abstract contract HookAggregator is DefaultBeforeAfterHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          SETUP                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Initializer for the hooks
    function _setUpHooks() internal {
        _setUpDefaultHooks();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HOOKS                                            //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Before hook for the handlers
    function _before() internal {
        _defaultHooksBefore();
    }

    /// @notice After hook for the handlers
    function _after() internal {
        _defaultHooksAfter();

        // POST-CONDITIONS
        _checkPostConditions();

        // Reset the state
        _resetState();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POSTCONDITION CHECKS                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Postconditions for the handlers
    function _checkPostConditions() internal {
        // Store the message signature to avoid losing it inside the checkPostConditions call context
        _cacheCurrentActionSignature();

        try this.checkPostConditions() {}
        catch (bytes memory returnData) {
            ErrorHandlers.handleAssertionError(false, returnData, true, GPOST_CHECK_FAILED);
        }
    }

    /// @dev postconditions checks entrypoint, should be self-called
    function checkPostConditions() external {
        // Target asset postconditions
        if (targetAssetId != 0) {
            assert_GPOST_HUB_C(targetAssetId);
        }

        // Protocol-wide postconditions
        uint256 assetCount = hub.getAssetCount();
        for (uint256 i; i < assetCount; i++) {
            assert_GPOST_HUB_A(i);
            assert_GPOST_HUB_B(i);
            assert_GPOST_HUB_D(i);
            assert_GPOST_HUB_G(i);

            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                address spoke = actorAddresses[j];
                assert_GPOST_HUB_EF(i, spoke);
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Resets the state of the handlers
    function _resetState() internal {
        delete currentActionSignature;
        delete targetAssetId;
    }
}
