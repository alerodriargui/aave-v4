// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {BaseHandler} from '../../base/BaseHandler.t.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

/// @title DonationAttackHandler
/// @notice Handler test contract for a set of actions
contract DonationAttackHandler is BaseHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function donateUnderlyingToHub(uint256 amount, uint8 i, uint8 j) external {
    // Get one of the hub addresses randomly
    address hubAddress = _getRandomHub(j);
    // Get one of the assets IDs randomly
    address underlying = _getRandomBaseAsset(i);

    TestnetERC20(underlying).mint(hubAddress, amount);
  }

  function donateUnderlyingToSpoke(uint256 amount, uint8 i, uint8 j) external {
    // Get one of the spoke addresses randomly
    address spoke = _getRandomSpoke(j);
    // Get one of the assets IDs randomly
    address underlying = _getRandomBaseAsset(i);

    TestnetERC20(underlying).mint(spoke, amount);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
