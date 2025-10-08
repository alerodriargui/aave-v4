// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHubConfiguratorHandler} from "../interfaces/IHubConfiguratorHandler.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../utils/Actor.sol";
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title HubConfiguratorHandler
/// @notice Handler test contract for a set of actions
contract HubConfiguratorHandler is BaseHandler, IHubConfiguratorHandler {
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

// TODO:
// updateLiquidityFee
// updateFeeConfig
// updateInterestRateStrategy
// freezeAsset
// pauseAsset
// updateSpokeActive
// updateSpokeSupplyCap
// updateSpokeDrawCap
// updateSpokeCaps
// pauseSpoke
// freezeSpoke
// updateInterestRateData

///////////////////////////////////////////////////////////////////////////////////////////////
//                                           HELPERS                                         //
///////////////////////////////////////////////////////////////////////////////////////////////
}
