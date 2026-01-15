// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ISpoke} from "src/spoke/interfaces/ISpoke.sol";
import {ISpokeHandler} from "../interfaces/ISpokeHandler.sol";
import {IERC20} from "src/dependencies/openzeppelin/IERC20.sol";

// Libraries
import {Constants} from "tests/Constants.sol";
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../../shared/utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

// Contracts
import {Spoke} from "src/spoke/Spoke.sol";
import {IHub} from "src/hub/interfaces/IHub.sol";

/// @title SpokeHandler
/// @notice Handler test contract for a set of actions
contract SpokeHandler is BaseHandler, ISpokeHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct LiquidationVars {
        // Spoke
        address violator;
        address liquidator;
        address spoke;
        address underlying;
        // Debt reserve
        uint256 debtReserveId;
        uint256 collateralReserveId;
        uint256 reserveDebtBefore;
        uint256 reserveDebtAfter;
        // Liquidation
        uint256 debtToCover;
        uint256 debtLiquidated;
        uint256 totalDebtValueBefore;
        // Liquidator
        uint256 liquidatorCollateralBalanceBefore;
        uint256 liquidatorCollateralBalanceAfter;
    }

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
            revert("SpokeHandler: supply failed");
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

        uint256 userAmount = IHub(_getHubAddress(spoke, reserveId))
            .previewRemoveByShares(reserveId, ISpoke(spoke).getUserSuppliedShares(reserveId, onBehalfOf));

        // Register user to check postconditions
        _registerUserToCheck(spoke, reserveId, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.withdraw, (reserveId, amount, onBehalfOf)));

        // Implemented outside the success check to assert success
        if (defaultVarsBefore.userVars[spoke][reserveId][onBehalfOf].totalDebt == 0 && (amount > 0 && userAmount != 0))
        {
            assertTrue(success, GPOST_SP_H);
        }

        if (success) {
            _after();
        } else {
            revert("SpokeHandler: withdraw failed");
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
        _registerUserToCheck(spoke, reserveId, onBehalfOf);

        // Check if user is healthy
        bool isHealthy = _isHealthy(spoke, onBehalfOf);

        _before();
        (success, returnData) = actor.proxy(spoke, abi.encodeCall(Spoke.borrow, (reserveId, amount, onBehalfOf)));

        if (success) {
            _after();

            ///// HSPOST /////

            assertTrue(isHealthy, HSPOST_SP_D);
        } else {
            revert("SpokeHandler: borrow failed");
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
            revert("SpokeHandler: repay failed");
        }
    }

    function liquidationCall(uint256 debtToCover, bool receiveShares, uint8 i, uint8 j, uint8 k, uint8 l)
        external
        setup
    {
        bool success;
        bytes memory returnData;

        LiquidationVars memory liquidationVars;

        // Get one of the three actors randomly
        liquidationVars.spoke = _getRandomSpoke(j);
        liquidationVars.debtToCover = debtToCover;

        liquidationVars.violator = _getRandomActor(i);
        liquidationVars.liquidator = address(actor);

        // Get both reserves IDs randomly and the collateral underlying asset
        liquidationVars.collateralReserveId = _getRandomReserveId(liquidationVars.spoke, k);
        liquidationVars.debtReserveId = _getRandomReserveId(liquidationVars.spoke, l);
        liquidationVars.underlying =
        ISpoke(liquidationVars.spoke).getReserve(liquidationVars.collateralReserveId).underlying;

        uint256 violatorCollateralBalanceBefore = ISpoke(liquidationVars.spoke)
            .getUserSuppliedAssets(liquidationVars.collateralReserveId, liquidationVars.violator);

        liquidationVars.totalDebtValueBefore =
        ISpoke(liquidationVars.spoke).getUserAccountData(_getRandomActor(i)).totalDebtValue;
        liquidationVars.reserveDebtBefore =
            ISpoke(liquidationVars.spoke).getReserveTotalDebt(liquidationVars.debtReserveId);

        if (receiveShares) {
            liquidationVars.liquidatorCollateralBalanceBefore = ISpoke(liquidationVars.spoke)
                .getUserSuppliedAssets(liquidationVars.collateralReserveId, address(actor));
        } else {
            liquidationVars.liquidatorCollateralBalanceBefore =
                IERC20(liquidationVars.underlying).balanceOf(address(actor));
        }

        // Register users to check postconditions: liquidated user and liquidator for both reserves
        _registerUserToCheck(liquidationVars.spoke, liquidationVars.debtReserveId, liquidationVars.violator);
        _registerUserToCheck(liquidationVars.spoke, liquidationVars.collateralReserveId, liquidationVars.violator);
        _registerUserToCheck(liquidationVars.spoke, liquidationVars.debtReserveId, liquidationVars.liquidator);
        _registerUserToCheck(liquidationVars.spoke, liquidationVars.collateralReserveId, liquidationVars.liquidator);

        _before();
        (success, returnData) = actor.proxy(
            liquidationVars.spoke,
            abi.encodeCall(
                Spoke.liquidationCall,
                (
                    liquidationVars.collateralReserveId,
                    liquidationVars.debtReserveId,
                    liquidationVars.violator,
                    liquidationVars.debtToCover,
                    receiveShares
                )
            )
        );

        if (success) {
            _after();

            // Calculate the debt liquidated
            liquidationVars.reserveDebtAfter =
                ISpoke(liquidationVars.spoke).getReserveTotalDebt(liquidationVars.debtReserveId);
            liquidationVars.debtLiquidated = (liquidationVars.reserveDebtBefore > liquidationVars.reserveDebtAfter)
                ? liquidationVars.reserveDebtBefore - liquidationVars.reserveDebtAfter
                : 0;

            if (receiveShares) {
                liquidationVars.liquidatorCollateralBalanceAfter = ISpoke(liquidationVars.spoke)
                    .getUserSuppliedAssets(liquidationVars.collateralReserveId, address(actor));
            } else {
                liquidationVars.liquidatorCollateralBalanceAfter =
                    IERC20(liquidationVars.underlying).balanceOf(address(actor));
            }

            ///// HSPOST /////
            assertLe(
                liquidationVars.debtLiquidated,
                defaultVarsBefore.userVars[liquidationVars.spoke][liquidationVars.debtReserveId][liquidationVars.violator].totalDebt,
                HSPOST_SP_LIQ_A
            );

            if (liquidationVars.liquidatorCollateralBalanceAfter > liquidationVars.liquidatorCollateralBalanceBefore) {
                assertLe(
                    liquidationVars.liquidatorCollateralBalanceAfter
                        - liquidationVars.liquidatorCollateralBalanceBefore,
                    violatorCollateralBalanceBefore,
                    HSPOST_SP_LIQ_B
                );
            }

            if (liquidationVars.totalDebtValueBefore < Constants.DUST_LIQUIDATION_THRESHOLD) {
                assertEq(
                    defaultVarsAfter.userVars[liquidationVars.spoke][liquidationVars.debtReserveId][_getRandomActor(
                            i
                        )].totalDebt,
                    0,
                    HSPOST_SP_LIQ_C
                );
            }

            assertGe(liquidationVars.debtToCover, liquidationVars.debtLiquidated, HSPOST_SP_LIQ_D);

            assertLt(
                defaultVarsBefore.userAccountDataVars[liquidationVars.spoke][_getRandomActor(i)].healthFactor,
                Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
                HSPOST_SP_LIQ_E
            );

            if (
                defaultVarsAfter.userVars[liquidationVars.spoke][liquidationVars.debtReserveId][_getRandomActor(
                            i
                        )].totalDebt > 0
            ) {
                assertGt(
                    defaultVarsAfter.userAccountDataVars[liquidationVars.spoke][_getRandomActor(i)].healthFactor,
                    defaultVarsBefore.userAccountDataVars[liquidationVars.spoke][_getRandomActor(i)].healthFactor,
                    HSPOST_SP_LIQ_G
                );
            }
        } else {
            revert("SpokeHandler: liquidationCall failed");
        }
    }

    function setUsingAsCollateral(bool usingAsCollateral, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;

        address onBehalfOf = address(actor);

        address spoke = _getRandomSpoke(i);

        uint256 reserveId = _getRandomReserveId(spoke, j);

        (bool isUsingAsCollateral,) = ISpoke(spoke).getUserReserveStatus(reserveId, onBehalfOf);

        require(usingAsCollateral != isUsingAsCollateral, "SpokeHandler: usingAsCollateral already set");

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
            revert("SpokeHandler: setUsingAsCollateral failed");
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
            assertEq(_getTotalDebt(spoke, onBehalfOf), totalDebt, HSPOST_SP_F);
        } else {
            revert("SpokeHandler: updateUserRiskPremium failed");
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
            revert("SpokeHandler: updateUserDynamicConfig failed");
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
