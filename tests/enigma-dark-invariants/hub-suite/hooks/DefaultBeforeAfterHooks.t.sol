// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {MathUtils} from "src/libraries/math/MathUtils.sol";
import {PercentageMath} from "src/libraries/math/PercentageMath.sol";
import "forge-std/console.sol";

// Utils
import {Actor} from "../../shared/utils/Actor.sol";
import {PropertiesConstants} from "../../shared/utils/PropertiesConstants.sol";
import {StdAsserts} from "../../shared/utils/StdAsserts.sol";

// Interfaces
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
        uint256 liquidity;
        uint256 deficit;
        uint256 swept;
        uint256 lastUpdateTimestamp;
        uint256 drawnRate;
    }

    struct SpokeDataVars {
        uint256 addedShares;
        uint256 drawnShares;
        uint256 premiumShares;
        uint256 premiumOffset;
        uint256 realizedPremium;
        uint256 deficit;
        uint256 drawn;
        uint256 premium;
    }

    struct DefaultVars {
        mapping(uint256 assetId => AssetVars) assetVars;
        mapping(uint256 assetId => mapping(address spoke => SpokeDataVars)) spokeDataVars;
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HOOKS STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Default variables before and after
    DefaultVars defaultVarsBefore;
    DefaultVars defaultVarsAfter;

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
        // Spoke data values
        _setSpokeDataValues(defaultVarsBefore);
    }

    function _defaultHooksAfter() internal {
        // Asset values
        _setAssetValues(defaultVarsAfter);
        // Spoke data values
        _setSpokeDataValues(defaultVarsAfter);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       HELPERS                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _setAssetValues(DefaultVars storage _defaultVars) internal {
        uint256 assetCount = hub.getAssetCount();
        for (uint256 j; j < assetCount; j++) {
            _defaultVars.assetVars[j].drawnIndex = hub.getAssetDrawnIndex(j);
            _defaultVars.assetVars[j].totalAssets = hub.getAddedAssets(j);
            _defaultVars.assetVars[j].totalShares = hub.getAddedShares(j);
            (_defaultVars.assetVars[j].drawn, _defaultVars.assetVars[j].premium) = hub.getAssetOwed(j);
            _defaultVars.assetVars[j].lastUpdateTimestamp = hub.getAsset(j).lastUpdateTimestamp;
            _defaultVars.assetVars[j].drawnRate = hub.getAssetDrawnRate(j);
            _defaultVars.assetVars[j].liquidity = hub.getAssetLiquidity(j);
            _defaultVars.assetVars[j].deficit = hub.getAssetDeficit(j);
            _defaultVars.assetVars[j].swept = hub.getAssetSwept(j);
        }
    }

    function _setSpokeDataValues(DefaultVars storage _defaultVars) internal {
        uint256 assetCount = hub.getAssetCount();

        for (uint256 i; i < assetCount; i++) {
            for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
                address spoke = actorAddresses[j];

                _defaultVars.spokeDataVars[i][spoke].addedShares = hub.getSpokeAddedShares(i, spoke);
                _defaultVars.spokeDataVars[i][spoke].drawnShares = hub.getSpokeDrawnShares(i, spoke);
                (
                    _defaultVars.spokeDataVars[i][spoke].premiumShares,
                    _defaultVars.spokeDataVars[i][spoke].premiumOffset,
                    _defaultVars.spokeDataVars[i][spoke].realizedPremium
                ) = hub.getSpokePremiumData(i, spoke);
                _defaultVars.spokeDataVars[i][spoke].deficit = hub.getSpokeDeficit(i, spoke);
                (_defaultVars.spokeDataVars[i][spoke].drawn, _defaultVars.spokeDataVars[i][spoke].premium) =
                    hub.getSpokeOwed(i, spoke);
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   POST CONDITIONS: HUB                                    //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function assert_GPOST_HUB_A(uint256 assetId) internal {
        assertGe(
            defaultVarsAfter.assetVars[assetId].drawnIndex, defaultVarsBefore.assetVars[assetId].drawnIndex, GPOST_HUB_A
        );
    }

    function assert_GPOST_HUB_B(uint256 assetId) internal {
        assertFullMulGe( // TODO review test_replay_1_supply
            defaultVarsAfter.assetVars[assetId].totalAssets,
            defaultVarsBefore.assetVars[assetId].totalShares,
            defaultVarsBefore.assetVars[assetId].totalAssets,
            defaultVarsAfter.assetVars[assetId].totalShares,
            GPOST_HUB_B
        );
    }

    function assert_GPOST_HUB_C(uint256 assetId) internal {
        // Read the cached signature of the current action
        bytes4 signature = currentActionSignature;
        if (true) {
            // TODO check which signatures need to be checked
            assertEq(
                hub.getAssetDrawnRate(assetId),
                IAssetInterestRateStrategy(irStrategy)
                    .calculateInterestRate(
                        assetId,
                        hub.getAssetLiquidity(assetId),
                        defaultVarsAfter.assetVars[assetId].drawn,
                        hub.getAssetDeficit(assetId),
                        hub.getAssetSwept(assetId)
                    ),
                GPOST_HUB_C
            );
        }
    }

    function assert_GPOST_HUB_D(uint256 assetId) internal {
        assertLe(defaultVarsAfter.assetVars[assetId].lastUpdateTimestamp, block.timestamp, GPOST_HUB_D);
    }

    function assert_GPOST_HUB_EF(uint256 assetId, address spoke) internal {
        // Get the spoke config
        IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, spoke);
        (, uint8 decimals) = hub.getAssetUnderlyingAndDecimals(assetId);

        // GPOST_HUB_E
        if (defaultVarsAfter.assetVars[assetId].totalAssets > defaultVarsBefore.assetVars[assetId].totalAssets) {
            if (spokeConfig.addCap != MAX_ALLOWED_SPOKE_CAP) {
                assertLe(
                    defaultVarsAfter.assetVars[assetId].totalAssets,
                    spokeConfig.addCap * MathUtils.uncheckedExp(10, decimals),
                    GPOST_HUB_E
                );
            }
        }

        // GPOST_HUB_F
        if (defaultVarsAfter.assetVars[assetId].drawn > defaultVarsBefore.assetVars[assetId].drawn) {
            if (spokeConfig.drawCap != MAX_ALLOWED_SPOKE_CAP) {
                assertLe(
                    defaultVarsAfter.assetVars[assetId].drawn,
                    spokeConfig.drawCap * MathUtils.uncheckedExp(10, decimals),
                    GPOST_HUB_F
                );
            }
        }
    }

    function assert_GPOST_HUB_G(uint256 assetId) internal {
        assertGe(
            defaultVarsAfter.assetVars[assetId].lastUpdateTimestamp,
            defaultVarsBefore.assetVars[assetId].lastUpdateTimestamp,
            GPOST_HUB_G
        );
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          HELPERS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    function _cacheCurrentActionSignature() internal {
        currentActionSignature = bytes4(msg.sig);
    }
}
