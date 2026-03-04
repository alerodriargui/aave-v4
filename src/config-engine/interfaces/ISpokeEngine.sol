// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title ISpokeEngine
/// @author Aave Labs
/// @notice Interface for the Spoke Engine contract.
interface ISpokeEngine {
  function executeSpokeReserveListings(
    IAaveV4ConfigEngine.ReserveListing[] calldata listings
  ) external;
  function executeSpokeReserveConfigUpdates(
    IAaveV4ConfigEngine.ReserveConfigUpdate[] calldata updates
  ) external;
  function executeSpokeLiquidationConfigUpdates(
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] calldata updates
  ) external;
  function executeSpokeDynamicReserveConfigAdditions(
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] calldata additions
  ) external;
  function executeSpokeDynamicReserveConfigUpdates(
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] calldata updates
  ) external;
  function executeSpokeAllReservesPauses(IAaveV4ConfigEngine.SpokePause[] calldata pauses) external;
  function executeSpokeAllReservesFreezes(
    IAaveV4ConfigEngine.SpokeFreeze[] calldata freezes
  ) external;
  function executeSpokePositionManagerUpdates(
    IAaveV4ConfigEngine.PositionManagerUpdate[] calldata updates
  ) external;
}
