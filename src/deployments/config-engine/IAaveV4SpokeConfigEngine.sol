// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title IAaveV4SpokeConfigEngine
/// @author Aave Labs
/// @notice Interface for the Spoke configuration engine.
/// @dev This engine is STATELESS and designed to be used via DELEGATECALL.
///      All functions receive spoke, spokeConfigurator, and hub addresses as parameters.
///      When called via DELEGATECALL, the caller's context is used — so the
///      caller (payload or executor) must hold the appropriate AccessManager roles.
interface IAaveV4SpokeConfigEngine {
  /// @notice Parameters for listing a new reserve on the Spoke.
  /// @param underlying The underlying asset address used to resolve assetId via hub.getAssetId().
  /// @param priceFeed The address of the Chainlink-compatible price feed.
  /// @param config The reserve configuration (collateralRisk, paused, frozen, borrowable, receiveSharesEnabled).
  /// @param dynamicConfig The dynamic reserve configuration (collateralFactor, maxLiquidationBonus, liquidationFee).
  struct ReserveListing {
    address underlying;
    address priceFeed;
    ISpoke.ReserveConfig config;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @notice Parameters for updating an existing reserve configuration.
  /// @param reserveId The identifier of the reserve on the Spoke.
  /// @param config The new reserve configuration.
  struct ReserveConfigUpdate {
    uint256 reserveId;
    ISpoke.ReserveConfig config;
  }

  /// @notice Parameters for updating a dynamic reserve configuration.
  /// @param reserveId The identifier of the reserve on the Spoke.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param config The new dynamic reserve configuration.
  struct DynamicConfigUpdate {
    uint256 reserveId;
    uint32 dynamicConfigKey;
    ISpoke.DynamicReserveConfig config;
  }

  /// @notice Wrapper for the spoke-wide liquidation configuration.
  /// @param config The liquidation config (targetHealthFactor, healthFactorForMaxBonus, liquidationBonusFactor).
  struct LiquidationConfigInput {
    ISpoke.LiquidationConfig config;
  }

  /// @notice Lists new reserves on the Spoke via the SpokeConfigurator.
  /// @dev Resolves assetId for each reserve via hub.getAssetId(underlying).
  /// @param spoke The Spoke contract address.
  /// @param spokeConfigurator The SpokeConfigurator contract address.
  /// @param hub The Hub contract address (used to resolve asset IDs).
  /// @param reserves The array of reserve listing parameters.
  /// @return reserveIds The array of newly created reserve IDs.
  function listReserves(
    address spoke,
    address spokeConfigurator,
    address hub,
    ReserveListing[] calldata reserves
  ) external returns (uint256[] memory reserveIds);

  /// @notice Updates the spoke-wide liquidation configuration via the SpokeConfigurator.
  /// @param spoke The Spoke contract address.
  /// @param spokeConfigurator The SpokeConfigurator contract address.
  /// @param input The liquidation configuration input.
  function updateLiquidationConfig(
    address spoke,
    address spokeConfigurator,
    LiquidationConfigInput calldata input
  ) external;

  /// @notice Updates existing reserve configurations on the Spoke.
  /// @param spoke The Spoke contract address.
  /// @param spokeConfigurator The SpokeConfigurator contract address.
  /// @param updates The array of reserve configuration updates.
  function updateReserves(
    address spoke,
    address spokeConfigurator,
    ReserveConfigUpdate[] calldata updates
  ) external;

  /// @notice Updates dynamic reserve configurations on the Spoke.
  /// @param spoke The Spoke contract address.
  /// @param spokeConfigurator The SpokeConfigurator contract address.
  /// @param updates The array of dynamic config updates.
  function updateDynamicConfigs(
    address spoke,
    address spokeConfigurator,
    DynamicConfigUpdate[] calldata updates
  ) external;
}
