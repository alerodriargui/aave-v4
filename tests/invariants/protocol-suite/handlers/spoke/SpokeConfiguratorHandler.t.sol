// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {ISpokeConfiguratorHandler} from '../interfaces/ISpokeConfiguratorHandler.sol';

// Libraries
import 'forge-std/console.sol';

// Test Contracts
import {Actor} from '../../../shared/utils/Actor.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title SpokeConfiguratorHandler
/// @notice Handler test contract for a set of actions
contract SpokeConfiguratorHandler is BaseHandler, ISpokeConfiguratorHandler {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function updateLiquidationTargetHealthFactor(uint256 targetHealthFactor, uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.updateLiquidationTargetHealthFactor(spoke, targetHealthFactor);
  }

  function updateHealthFactorForMaxBonus(uint256 healthFactorForMaxBonus, uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.updateHealthFactorForMaxBonus(spoke, healthFactorForMaxBonus);
  }

  function updateLiquidationBonusFactor(uint256 liquidationBonusFactor, uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.updateLiquidationBonusFactor(spoke, liquidationBonusFactor);
  }

  function updatePaused(bool paused, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updatePaused(spoke, reserveId, paused);
  }

  function updateFrozen(bool frozen, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updateFrozen(spoke, reserveId, frozen);
  }

  function updateBorrowable(bool borrowable, uint8 i, uint8 j) external setup {
    address spoke = _getRandomSpoke(i);
    uint256 reserveId = _getRandomReserveId(spoke, j);
    spokeConfigurator.updateBorrowable(spoke, reserveId, borrowable);
  }

  function pauseAllReserves(uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.pauseAllReserves(spoke);
  }

  function freezeAllReserves(uint8 i) external setup {
    address spoke = _getRandomSpoke(i);
    spokeConfigurator.freezeAllReserves(spoke);
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
