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
        // Hub postconditions
        _hubPostConditions();
        // Spoke postconditions
        _spokePostConditions();
    }

    function _hubPostConditions() internal {
        // Iterate through all users to check
        for (uint256 i; i < usersToCheck.length; i++) {
            // Avoid checking postconditions for CHECK_ALL_RESERVES actions
            if (usersToCheck[i].reserveId != CHECK_ALL_RESERVES) {
                uint256 assetId = _getAssetId(usersToCheck[i].spoke, usersToCheck[i].reserveId);
                address hubAddress = _getHubAddress(usersToCheck[i].spoke, usersToCheck[i].reserveId);

                assert_GPOST_HUB_A(hubAddress, assetId);
                assert_GPOST_HUB_B(hubAddress, assetId);
                assert_GPOST_HUB_C(hubAddress, assetId);
                assert_GPOST_HUB_D(hubAddress, assetId);
                assert_GPOST_HUB_EF(hubAddress, assetId, usersToCheck[i].spoke);
                assert_GPOST_HUB_G(hubAddress, assetId);
            }
        }
    }

    function _spokePostConditions() internal {
        // Iterate through all users to check
        for (uint256 i; i < usersToCheck.length; i++) {
            uint256 reserveId = usersToCheck[i].reserveId;
            address spoke = usersToCheck[i].spoke;
            address user = usersToCheck[i].user;

            // Check properties for all reserves of the spoke, used after actions: updateUserRiskPremium, updateUserDynamicConfig
            if (reserveId == CHECK_ALL_RESERVES) {
                // Iterate through all reserves of the spoke
                for (uint256 j; j < spokeReserveIds[spoke].length; j++) {
                    assert_GPOST_SP_A(spoke, spokeReserveIds[spoke][i], user);
                    assert_GPOST_SP_B(spoke, spokeReserveIds[spoke][i], user);
                    assert_GPOST_SP_E(spoke, spokeReserveIds[spoke][i], user);
                }
            } else {
                // Check properties for a specific reserve of the spoke, used after actions: supply, withdraw, borrow, repay, setUsingAsCollateral
                assert_GPOST_SP_A(spoke, reserveId, user);
                assert_GPOST_SP_B(spoke, reserveId, user);
                assert_GPOST_SP_E(spoke, reserveId, user);
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Resets the state of the handlers
    function _resetState() internal {
        delete usersToCheck;
        delete currentActionSignature;
    }
}
