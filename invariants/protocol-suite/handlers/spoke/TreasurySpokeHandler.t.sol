// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ITreasurySpokeHandler} from '../interfaces/ITreasurySpokeHandler.sol';
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';

// Libraries
import 'forge-std/console.sol';

// Test Contracts
import {BaseHandler} from '../../base/BaseHandler.t.sol';

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

  function supply(uint256 amount, uint8 i, uint8 j) external {
    // TODO fix coverage issues
    // Get one of the hub addresses randomly
    address hubAddress = _getRandomHub(i);
    address treasurySpoke = hubInfo[hubAddress].treasurySpoke;

    // Get one of the reserves IDs randomly
    uint256 reserveId = _getRandomReserveId(treasurySpoke, j);

    _before();
    try ITreasurySpoke(treasurySpoke).supply(reserveId, amount, msg.sender) {
      _after();
    } catch {
      revert('TreasurySpokeHandler: supply failed');
    }
  }

  function withdraw(uint256 amount, uint8 i, uint8 j) external {
    // Get one of the hub addresses randomly
    address hubAddress = _getRandomHub(i);
    address treasurySpoke = hubInfo[hubAddress].treasurySpoke;

    // Get one of the reserves IDs randomly
    uint256 reserveId = _getRandomReserveId(treasurySpoke, j);

    _before();
    try ITreasurySpoke(treasurySpoke).withdraw(reserveId, amount, msg.sender) {
      _after();
    } catch {
      revert('TreasurySpokeHandler: withdraw failed');
    }
  }

  function transfer(uint256 amount, uint8 i, uint8 j, uint8 k) external {
    // Get one of the hub addresses randomly
    address hubAddress = _getRandomHub(i);

    // Get one of the assets IDs randomly
    address asset = _getRandomBaseAsset(j);

    // Get one of the actors randomly
    address to = _getRandomActor(k);

    _before();
    try ITreasurySpoke(hubInfo[hubAddress].treasurySpoke).transfer(asset, to, amount) {
      _after();
    } catch {
      revert('TreasurySpokeHandler: transfer failed');
    }
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
