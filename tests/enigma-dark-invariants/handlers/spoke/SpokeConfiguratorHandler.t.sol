// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {ISpokeConfiguratorHandler} from "../interfaces/ISpokeConfiguratorHandler.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title SpokeConfiguratorHandler
/// @notice Handler test contract for a set of actions
contract SpokeConfiguratorHandler is BaseHandler, ISpokeConfiguratorHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////
/* 
    
    E.g. num of active pools
    uint256 public activePools;
        
    */

///////////////////////////////////////////////////////////////////////////////////////////////
//                                          ACTIONS                                          //
///////////////////////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////////////////////
//                                         OWNER ACTIONS                                     //
///////////////////////////////////////////////////////////////////////////////////////////////

// TODO
// updateLiquidationTargetHealthFactor
// updateHealthFactorForMaxBonus
// updateLiquidationBonusFactor
// updateLiquidationConfig
// updatePaused
// updateFrozen
// updateBorrowable
// updateCollateralRisk
// addCollateralFactor
// updateCollateralFactor
// addLiquidationBonus
// updateMaxLiquidationBonus
// addLiquidationFee
// updateLiquidationFee
// addDynamicReserveConfig
// updateDynamicReserveConfig
// pauseAllReserves
// freezeAllReserves

///////////////////////////////////////////////////////////////////////////////////////////////
//                                           HELPERS                                         //
///////////////////////////////////////////////////////////////////////////////////////////////
}
