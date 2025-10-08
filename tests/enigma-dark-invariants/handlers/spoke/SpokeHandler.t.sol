// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ISpoke} from "src/spoke/interfaces/ISpoke.sol";
import {ISpokeHandler} from "../interfaces/ISpokeHandler.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Contracts
import {Spoke} from "src/spoke/Spoke.sol";

/// @title SpokeHandler
/// @notice Handler test contract for a set of actions
contract SpokeHandler is BaseHandler, ISpokeHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // Used on the liquidation handler to store the collateral and debt reserve IDs and avoid stack to deep errors
    /// @dev should be zeroed after each liquidation call
    uint256 internal collateralReserveId;
    uint256 internal debtReserveId;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function supply(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address onBehalfOf = _getRandomActor(i);

        address spoke = _getRandomSpoke(j);

        // Get one of the reserves IDs randomly
        uint256 reserveId = _getReserveId(spoke, k);

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.supply, (reserveId, amount, onBehalfOf)));

        if (success) {
            _after();
        } else {
            revert("DefaultHandler: supply failed");
        }
    }

    function withdraw(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address onBehalfOf = _getRandomActor(i);

        address spoke = _getRandomSpoke(j);

        // Get one of the reserves IDs randomly
        uint256 reserveId = _getReserveId(spoke, k);

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, address(actor));

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.withdraw, (reserveId, amount, onBehalfOf)));

        if (success) {
            _after();
        } else {
            revert("DefaultHandler: withdraw failed");
        }
    }

    function borrow(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address onBehalfOf = _getRandomActor(i);

        address spoke = _getRandomSpoke(j);

        // Get one of the reserves IDs randomly
        uint256 reserveId = _getReserveId(spoke, k);

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, address(actor));

        // Check if user is healthy
        bool isHealthy = _isHealthy(spoke, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.borrow, (reserveId, amount, onBehalfOf)));

        if (success) {
            _after();

            ///// HSPOST /////

            assertTrue(isHealthy, HSPOST_SP_D);
        } else {
            revert("DefaultHandler: borrow failed");
        }
    }

    function repay(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address onBehalfOf = _getRandomActor(i);

        address spoke = _getRandomSpoke(j);

        // Get one of the reserves IDs randomly
        uint256 reserveId = _getReserveId(spoke, k);

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.repay, (reserveId, amount, onBehalfOf)));

        if (success) {
            _after();

            ///// HSPOST /////

            assertLt(
                defaultVarsAfter.userVars[spoke][reserveId][onBehalfOf].totalDebt,
                defaultVarsBefore.userVars[spoke][reserveId][onBehalfOf].totalDebt,
                HSPOST_SP_C
            );
        } else {
            revert("DefaultHandler: repay failed");
        }
    }

    function liquidationCall(uint256 debtToCover, uint8 i, uint8 j, uint8 k, uint8 l) external setup {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address spoke = _getRandomSpoke(j);

        // Get one of the reserves IDs randomly
        collateralReserveId = _getReserveId(spoke, k);
        debtReserveId = _getReserveId(spoke, l);

        uint256 debtValueInBaseCurrency = ISpoke(spoke).getUserAccountData(_getRandomActor(i)).totalDebtInBaseCurrency;

        // Register users to check postconditions: liquidated user and liquidator for both reserves
        _registerUserToCheck(spoke, debtReserveId, _getRandomActor(i));
        _registerUserToCheck(spoke, collateralReserveId, _getRandomActor(i));
        _registerUserToCheck(spoke, debtReserveId, address(actor));
        _registerUserToCheck(spoke, collateralReserveId, address(actor));

        _before();
        (success, returnData) = actor.proxy(
            spoke,
            abi.encodeCall(Spoke.liquidationCall, (collateralReserveId, debtReserveId, _getRandomActor(i), debtToCover))
        );

        if (success) {
            _after();

            ///// HSPOST /////

            uint256 userTotalDebt = ISpoke(spoke).getUserTotalDebt(debtReserveId, _getRandomActor(i));

            assertLt(debtToCover, userTotalDebt, HSPOST_SP_LIQ_A);

            if (debtValueInBaseCurrency > ISpoke(spoke).DUST_DEBT_LIQUIDATION_THRESHOLD()) {
                assertEq(userTotalDebt, 0, HSPOST_SP_LIQ_C);
            }
        } else {
            revert("DefaultHandler: liquidationCall failed");
        }

        delete collateralReserveId;
        delete debtReserveId;
    }

    function setUsingAsCollateral(bool usingAsCollateral, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        address onBehalfOf = address(actor);

        address spoke = _getRandomSpoke(i);

        uint256 reserveId = _getReserveId(spoke, j);

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, onBehalfOf);

        _before();
        (success, returnData) =
            actor.proxy(spoke, abi.encodeCall(Spoke.setUsingAsCollateral, (reserveId, usingAsCollateral, onBehalfOf)));

        if (success) {
            _after();
        } else {
            revert("DefaultHandler: setUsingAsCollateral failed");
        }
    }

    function updateUserRiskPremium(uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address onBehalfOf = address(actor);

        address spoke = _getRandomSpoke(i);

        uint256 totalDebt = _getTotalDebt(spoke, onBehalfOf);

        // Register user to check postconditions
        _registerUserToCheck(spoke, CHECK_ALL_RESERVES, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.updateUserRiskPremium, (onBehalfOf)));

        if (success) {
            _after();

            ///// HSPOST /////

            assertApproxEqAbs(
                totalDebt, totalDebt, 2, HSPOST_SP_F
            );
        } else {
            revert("DefaultHandler: updateUserRiskPremium failed");
        }
    }

    function updateUserDynamicConfig(uint8 i) external setup {
        bool success;
        bytes memory returnData;

        address onBehalfOf = address(actor);

        address spoke = _getRandomSpoke(i);

        _registerUserToCheck(spoke, CHECK_ALL_RESERVES, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.updateUserDynamicConfig, (onBehalfOf)));

        if (success) {
            _after();
        } else {
            revert("DefaultHandler: updateUserDynamicConfig failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // TODO
    // Configurator:
    // updateLiquidationConfig
    // updateReserveConfig
    // addDynamicReserveConfig
    // updateDynamicReserveConfig

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _getTotalDebt(address spoke, address user) internal view returns (uint256) {
        uint256 totalDebt;
        uint256 reserveCount = spokeReserveIds[spoke].length;
        for (uint256 i; i < reserveCount; i++) {
            totalDebt += ISpoke(spoke).getUserTotalDebt(spokeReserveIds[spoke][i], user);
        }
        return totalDebt;
    }
}
