// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {MathUtils} from "src/libraries/math/MathUtils.sol";
import {PercentageMath} from "src/libraries/math/PercentageMath.sol";
import "forge-std/console.sol";

// Utils
import {Constants} from "tests/Constants.sol";

// Interfaces
import {ISpokeHandler} from "../handlers/interfaces/ISpokeHandler.sol";
import {ISpoke} from "src/spoke/interfaces/ISpoke.sol";
import {IHub} from "src/hub/interfaces/IHub.sol";
import {IAssetInterestRateStrategy} from "src/hub/interfaces/IAssetInterestRateStrategy.sol";

// Contracts
import {BaseHooks} from "../base/BaseHooks.t.sol";

/// @title DefaultBeforeAfterHooks
/// @notice Helper contract for before and after hooks, state variable caching and postconditions
/// @dev This contract is inherited by handlers
abstract contract DefaultBeforeAfterHooks is BaseHooks {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         STRUCTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct AssetVars {
        uint256 drawnIndex;
        uint256 totalAssets;
        uint256 totalShares;
        uint256 drawn;
        uint256 premium;
        uint256 lastUpdateTimestamp;
    }

    struct UserVars {
        uint256 drawnDebt;
        uint256 premiumDebt;
        uint256 totalDebt;
    }

    struct UserAccountDataVars {
        uint256 healthFactor;
    }

    struct DefaultVars {
        mapping(address hub => mapping(uint256 assetId => AssetVars)) assetVars;
        mapping(address spoke => mapping(uint256 reserveId => mapping(address user => UserVars))) userVars;
        mapping(address spoke => mapping(address user => UserAccountDataVars)) userAccountDataVars;
    }

    struct UserInfo {
        address spoke;
        uint256 reserveId;
        address user;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Default variables before and after
    DefaultVars defaultVarsBefore;
    DefaultVars defaultVarsAfter;

    // Temp array of users to check postconditions for, reset after each handler on _resetState
    UserInfo[] usersToCheck;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           SETUP                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Default hooks setup
    function _setUpDefaultHooks() internal {}

    /// @notice Helper to initialize storage arrays of default vars
    function _setUpDefaultVars(DefaultVars storage _defaultVars) internal {}

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HOOKS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _defaultHooksBefore() internal {
        // Asset values
        _setAssetValues(defaultVarsBefore);
        // User values
        _setUserValues(defaultVarsBefore);
    }

    function _defaultHooksAfter() internal {
        // Asset values
        _setAssetValues(defaultVarsAfter);
        // User values
        _setUserValues(defaultVarsAfter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HELPERS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setAssetValues(DefaultVars storage _defaultVars) internal {
        for (uint256 i; i < hubAddresses.length; i++) {
            address hubAddress = hubAddresses[i];
            uint256 assetCount = IHub(hubAddress).getAssetCount();
            for (uint256 j; j < assetCount; j++) {
                _defaultVars.assetVars[hubAddress][j].drawnIndex = IHub(hubAddress).getAssetDrawnIndex(j);
                _defaultVars.assetVars[hubAddress][j].totalAssets = IHub(hubAddress).getAddedAssets(j);
                _defaultVars.assetVars[hubAddress][j].totalShares = IHub(hubAddress).getAddedShares(j);
                (_defaultVars.assetVars[hubAddress][j].drawn, _defaultVars.assetVars[hubAddress][j].premium) =
                    IHub(hubAddress).getAssetOwed(j);
                _defaultVars.assetVars[hubAddress][j].lastUpdateTimestamp =
                IHub(hubAddress).getAsset(j).lastUpdateTimestamp;
            }
        }
    }

    function _setUserValues(DefaultVars storage _defaultVars) internal {
        // Iterate through all users to check
        for (uint256 i; i < usersToCheck.length; i++) {
            UserInfo memory userInfo = usersToCheck[i];

            // Cache values for the user's account data
            ISpoke.UserAccountData memory userAccountData = ISpoke(userInfo.spoke).getUserAccountData(userInfo.user);
            _defaultVars.userAccountDataVars[userInfo.spoke][userInfo.user].healthFactor = userAccountData.healthFactor;

            // Cache values for all reserves of the spoke, used after actions: updateUserRiskPremium, updateUserDynamicConfig
            if (userInfo.reserveId == CHECK_ALL_RESERVES) {
                // Iterate through all reserves of the spoke
                for (uint256 j; j < spokeReserveIds[userInfo.spoke].length; j++) {
                    (
                        _defaultVars.userVars[userInfo.spoke][spokeReserveIds[userInfo.spoke][j]][userInfo.user].drawnDebt,
                        _defaultVars.userVars[userInfo.spoke][spokeReserveIds[userInfo.spoke][j]][userInfo.user]
                            .premiumDebt
                    ) = ISpoke(userInfo.spoke).getUserDebt(spokeReserveIds[userInfo.spoke][j], userInfo.user);
                    _defaultVars.userVars[userInfo.spoke][spokeReserveIds[userInfo.spoke][j]][userInfo.user].totalDebt =
                        ISpoke(userInfo.spoke).getUserTotalDebt(spokeReserveIds[userInfo.spoke][j], userInfo.user);
                }
            } else {
                // Cache values for a specific reserve of the spoke, used after actions: supply, withdraw, borrow, repay, setUsingAsCollateral
                (, _defaultVars.userVars[userInfo.spoke][userInfo.reserveId][userInfo.user].premiumDebt) =
                    ISpoke(userInfo.spoke).getUserDebt(userInfo.reserveId, userInfo.user);
                _defaultVars.userVars[userInfo.spoke][userInfo.reserveId][userInfo.user].totalDebt =
                    ISpoke(userInfo.spoke).getUserTotalDebt(userInfo.reserveId, userInfo.user);
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: HUB                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_HUB_A(address hubAddress, uint256 assetId) internal {
        assertGe(
            defaultVarsAfter.assetVars[hubAddress][assetId].drawnIndex,
            defaultVarsBefore.assetVars[hubAddress][assetId].drawnIndex,
            GPOST_HUB_A
        );
    }

    function assert_GPOST_HUB_B(address hubAddress, uint256 assetId) internal {
        assertFullMulGe( // TODO review test_replay_1_supply
            defaultVarsAfter.assetVars[hubAddress][assetId].totalAssets,
            defaultVarsBefore.assetVars[hubAddress][assetId].totalShares,
            defaultVarsBefore.assetVars[hubAddress][assetId].totalAssets,
            defaultVarsAfter.assetVars[hubAddress][assetId].totalShares,
            GPOST_HUB_B
        );
    }

    function assert_GPOST_HUB_C(address hubAddress, uint256 assetId) internal {
        // Read the cached signature of the current action
        bytes4 signature = currentActionSignature;
        if (
            signature == ISpokeHandler.supply.selector || signature == ISpokeHandler.withdraw.selector
                || signature == ISpokeHandler.borrow.selector || signature == ISpokeHandler.repay.selector
                || signature == ISpokeHandler.updateUserRiskPremium.selector
        ) {
            assertEq(
                IHub(hubAddress).getAssetDrawnRate(assetId),
                IAssetInterestRateStrategy(hubInfo[hubAddress].irStrategy)
                    .calculateInterestRate(
                        assetId,
                        IHub(hubAddress).getAssetLiquidity(assetId),
                        defaultVarsAfter.assetVars[hubAddress][assetId].drawn,
                        0, // Unused in the interest rate calculation
                        IHub(hubAddress).getAssetSwept(assetId)
                    ),
                GPOST_HUB_C
            );
        }
    }

    function assert_GPOST_HUB_D(address hubAddress, uint256 assetId) internal {
        assertLe(defaultVarsAfter.assetVars[hubAddress][assetId].lastUpdateTimestamp, block.timestamp, GPOST_HUB_D);
    }

    function assert_GPOST_HUB_EF(address hubAddress, uint256 assetId, address spoke) internal {
        // Get the spoke config
        IHub.SpokeConfig memory spokeConfig = IHub(hubAddress).getSpokeConfig(assetId, spoke);
        (, uint8 decimals) = IHub(hubAddress).getAssetUnderlyingAndDecimals(assetId);

        // GPOST_HUB_E
        if (
            defaultVarsAfter.assetVars[hubAddress][assetId].totalAssets
                > defaultVarsBefore.assetVars[hubAddress][assetId].totalAssets
        ) {
            if (spokeConfig.addCap != MAX_ALLOWED_SPOKE_CAP) {
                assertLe(
                    defaultVarsAfter.assetVars[hubAddress][assetId].totalAssets,
                    spokeConfig.addCap * MathUtils.uncheckedExp(10, decimals),
                    GPOST_HUB_E
                );
            }
        }

        // GPOST_HUB_F
        if (
            defaultVarsAfter.assetVars[hubAddress][assetId].drawn
                > defaultVarsBefore.assetVars[hubAddress][assetId].drawn
        ) {
            if (spokeConfig.drawCap != MAX_ALLOWED_SPOKE_CAP) {
                assertLe(
                    defaultVarsAfter.assetVars[hubAddress][assetId].drawn,
                    spokeConfig.drawCap * MathUtils.uncheckedExp(10, decimals),
                    GPOST_HUB_F
                );
            }
        }
    }

    function assert_GPOST_HUB_G(address hubAddress, uint256 assetId) internal {
        assertGe(
            defaultVarsAfter.assetVars[hubAddress][assetId].lastUpdateTimestamp,
            defaultVarsBefore.assetVars[hubAddress][assetId].lastUpdateTimestamp,
            GPOST_HUB_G
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: SPOKE                                  //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_SP_A(address spoke, uint256 reserveId, address user) internal {
        ISpoke.UserPosition memory userPosition = ISpoke(spoke).getUserPosition(reserveId, user);
        uint256 userRiskPremium = ISpoke(spoke).getUserAccountData(user).riskPremium;

        uint256 expected = PercentageMath.percentMulUp(userPosition.drawnShares, userRiskPremium);
        assertEq(userPosition.premiumShares, expected, GPOST_SP_A);
    }

    function assert_GPOST_SP_B(address spoke, uint256 reserveId, address user) internal {
        if (
            defaultVarsAfter.userVars[spoke][reserveId][user].premiumDebt
                < defaultVarsBefore.userVars[spoke][reserveId][user].premiumDebt
        ) {
            assertTrue(
                currentActionSignature == ISpokeHandler.repay.selector
                    || currentActionSignature == ISpokeHandler.liquidationCall.selector,
                GPOST_SP_B
            );
        }

        if (
            defaultVarsAfter.userVars[spoke][reserveId][user].drawnDebt
                < defaultVarsBefore.userVars[spoke][reserveId][user].drawnDebt
        ) {
            assertTrue(
                currentActionSignature == ISpokeHandler.repay.selector
                    || currentActionSignature == ISpokeHandler.liquidationCall.selector,
                GPOST_SP_B2
            );
            assertEq(defaultVarsAfter.userVars[spoke][reserveId][user].premiumDebt, 0, GPOST_SP_B2);
        }
    }

    function assert_GPOST_SP_E(address spoke, uint256 reserveId, address user) internal {
        // latest reserve key
        uint24 latestKey = ISpoke(spoke).getReserve(reserveId).dynamicConfigKey;
        // user-stored key
        uint24 userKey = ISpoke(spoke).getUserPosition(reserveId, user).dynamicConfigKey;

        // Read the cached signature of the current action
        bytes4 signature = currentActionSignature;

        if (
            signature == ISpokeHandler.borrow.selector || signature == ISpokeHandler.withdraw.selector
                || signature == ISpokeHandler.setUsingAsCollateral.selector
                || signature == ISpokeHandler.updateUserDynamicConfig.selector
        ) {
            assertEq(latestKey, userKey, GPOST_SP_E);
        }
    }

    function assert_GPOST_LIQ_G(address spoke, address user) internal {
        // Read the cached values of the user's health factor
        uint256 healthFactorBefore = defaultVarsBefore.userAccountDataVars[spoke][user].healthFactor;
        uint256 healthFactorAfter = defaultVarsAfter.userAccountDataVars[spoke][user].healthFactor;

        // Read the cached signature of the current action
        bytes4 signature = currentActionSignature;

        if (
            healthFactorBefore < Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD && healthFactorAfter < healthFactorBefore
        ) {
            assertTrue(signature == ISpokeHandler.liquidationCall.selector, GPOST_SP_LIQ_G);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _registerUserToCheck(address spoke, uint256 reserveId, address user) internal {
        usersToCheck.push(UserInfo(spoke, reserveId, user));
    }

    function _cacheCurrentActionSignature() internal {
        currentActionSignature = bytes4(msg.sig);
    }
}
