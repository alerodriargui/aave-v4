// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ITreasurySpokeHandler} from "../interfaces/ITreasurySpokeHandler.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {BaseHandler} from "../../base/BaseHandler.t.sol";

/// @title TreasurySpokeHandler
/// @notice Handler test contract for a set of actions
contract TreasurySpokeHandler is BaseHandler, ITreasurySpokeHandler {
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

    function supply(uint256 amount, uint8 i) external setup {
        // Get one of the reserves IDs randomly
        uint256 reserveId = _getRandomReserveId(address(treasurySpoke), i);

        _before();
        try treasurySpoke.supply(reserveId, amount, msg.sender) {
            _after();
        } catch {
            revert("DefaultHandler: supply failed");
        }
    }

    function withdraw(uint256 amount, uint8 i) external setup {
        // Get one of the reserves IDs randomly
        uint256 reserveId = _getRandomReserveId(address(treasurySpoke), i);

        _before();
        try treasurySpoke.withdraw(reserveId, amount, msg.sender) {
            _after();
        } catch {
            revert("DefaultHandler: withdraw failed");
        }
    }

    function transfer(uint256 amount, uint8 i, uint8 j) external setup {
        // Get one of the actors randomly
        address to = _getRandomActor(i);

        // Get one of the assets IDs randomly
        address asset = _getRandomBaseAsset(j);

        _before();
        try treasurySpoke.transfer(asset, to, amount) {
            _after();
        } catch {
            revert("DefaultHandler: transfer failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
