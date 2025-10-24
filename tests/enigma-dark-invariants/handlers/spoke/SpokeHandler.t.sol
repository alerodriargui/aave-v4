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
    uint256 internal totalDebtValueBefore;

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
        uint256 reserveId = _getRandomReserveId(spoke, k);

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
        uint256 reserveId = _getRandomReserveId(spoke, k);

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
        uint256 reserveId = _getRandomReserveId(spoke, k);

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
        uint256 reserveId = _getRandomReserveId(spoke, k);

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.repay, (reserveId, amount, onBehalfOf)));

        if (success) {
            _after();

            ///// HSPOST /////

            assertLe(
                defaultVarsAfter.userVars[spoke][reserveId][onBehalfOf].totalDebt,
                defaultVarsBefore.userVars[spoke][reserveId][onBehalfOf].totalDebt,
                HSPOST_SP_C
            );
        } else {
            revert("DefaultHandler: repay failed");
        }
    }

    function liquidationCall(uint256 debtToCover, bool receiveShares, uint8 i, uint8 j, uint8 k, uint8 l)
        external
        setup
    {
        bool success;
        bytes memory returnData;

        // Get one of the three actors randomly
        address spoke = _getRandomSpoke(j);

        // Get one of the reserves IDs randomly
        collateralReserveId = _getRandomReserveId(spoke, k);
        debtReserveId = _getRandomReserveId(spoke, l);

        totalDebtValueBefore = ISpoke(spoke).getUserAccountData(_getRandomActor(i)).totalDebtValue;
        uint256 reserveDebtBefore = ISpoke(spoke).getReserveTotalDebt(debtReserveId);

        // Register users to check postconditions: liquidated user and liquidator for both reserves
        _registerUserToCheck(spoke, debtReserveId, _getRandomActor(i));
        _registerUserToCheck(spoke, collateralReserveId, _getRandomActor(i));
        _registerUserToCheck(spoke, debtReserveId, address(actor));
        _registerUserToCheck(spoke, collateralReserveId, address(actor));

        _before();
        (success, returnData) = actor.proxy(
            spoke,
            abi.encodeCall(
                Spoke.liquidationCall,
                (collateralReserveId, debtReserveId, _getRandomActor(i), debtToCover, receiveShares)
            )
        );

        if (success) {
            _after();

            // Calculate the debt liquidated
            uint256 reserveDebtAfter = ISpoke(spoke).getReserveTotalDebt(debtReserveId);
            uint256 debtLiquidated = (reserveDebtBefore > reserveDebtAfter) ? reserveDebtBefore - reserveDebtAfter : 0;

            ///// HSPOST /////
            assertLe(
                debtLiquidated,
                defaultVarsBefore.userVars[spoke][debtReserveId][_getRandomActor(i)].totalDebt,
                HSPOST_SP_LIQ_A
            );

            if (totalDebtValueBefore < ISpoke(spoke).DUST_LIQUIDATION_THRESHOLD()) {
                assertEq(
                    defaultVarsAfter.userVars[spoke][debtReserveId][_getRandomActor(i)].totalDebt, 0, HSPOST_SP_LIQ_C
                );
            }

            assertGe(debtToCover, debtLiquidated, HSPOST_SP_LIQ_D);
        } else {
            revert("DefaultHandler: liquidationCall failed");
        }

        delete collateralReserveId;
        delete debtReserveId;
        delete totalDebtValueBefore;
    }

    function setUsingAsCollateral(bool usingAsCollateral, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        address onBehalfOf = address(actor);

        address spoke = _getRandomSpoke(i);

        uint256 reserveId = _getRandomReserveId(spoke, j);

        // Register user to check postconditions
        /// @dev setUsingAsCollateral(reserveId, FALSE) all reserves in user position should be refreshed,
        ///      so we check all reserves in user position
        ///      setUsingAsCollateral(reserveId, TRUE) only reserveId in user position should be refreshed,
        ///      so we check only the reserveId in user position
        _registerUserToCheck(spoke, (usingAsCollateral ? reserveId : CHECK_ALL_RESERVES), onBehalfOf);

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

            assertApproxEqAbs(totalDebt, totalDebt, 2, HSPOST_SP_F);
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
