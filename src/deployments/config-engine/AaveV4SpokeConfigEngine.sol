// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IAaveV4SpokeConfigEngine} from 'src/deployments/config-engine/IAaveV4SpokeConfigEngine.sol';

/// @title AaveV4SpokeConfigEngine
/// @author Aave Labs
/// @notice Stateless engine for Spoke-side configuration: listing reserves, updating liquidation
///         config, and updating reserve/dynamic configs.
/// @dev This contract is STATELESS and designed to be called via DELEGATECALL.
///      When used via DELEGATECALL, the calling contract's context (address, roles) is used.
///      The caller must hold the appropriate AccessManager roles (e.g., SPOKE_CONFIGURATOR_ADMIN_ROLE).
contract AaveV4SpokeConfigEngine is IAaveV4SpokeConfigEngine {
  /// @inheritdoc IAaveV4SpokeConfigEngine
  function listReserves(
    address spoke,
    address spokeConfigurator,
    address hub,
    ReserveListing[] calldata reserves
  ) external returns (uint256[] memory reserveIds) {
    uint256 len = reserves.length;
    reserveIds = new uint256[](len);

    for (uint256 i; i < len; i++) {
      ReserveListing calldata reserve = reserves[i];

      // Resolve assetId from underlying address
      uint256 assetId = IHub(hub).getAssetId(reserve.underlying);

      reserveIds[i] = ISpokeConfigurator(spokeConfigurator).addReserve(
        spoke,
        hub,
        assetId,
        reserve.priceFeed,
        reserve.config,
        reserve.dynamicConfig
      );
    }
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function updateLiquidationConfig(
    address spoke,
    address spokeConfigurator,
    LiquidationConfigInput calldata input
  ) external {
    ISpokeConfigurator(spokeConfigurator).updateLiquidationConfig(spoke, input.config);
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function updateReserves(
    address spoke,
    address spokeConfigurator,
    ReserveConfigUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      ReserveConfigUpdate calldata update = updates[i];
      if (update.config.paused) {
        ISpokeConfigurator(spokeConfigurator).updatePaused(spoke, update.reserveId, true);
      }
      if (update.config.frozen) {
        ISpokeConfigurator(spokeConfigurator).updateFrozen(spoke, update.reserveId, true);
      }
      ISpokeConfigurator(spokeConfigurator).updateBorrowable(
        spoke,
        update.reserveId,
        update.config.borrowable
      );
      ISpokeConfigurator(spokeConfigurator).updateReceiveSharesEnabled(
        spoke,
        update.reserveId,
        update.config.receiveSharesEnabled
      );
      ISpokeConfigurator(spokeConfigurator).updateCollateralRisk(
        spoke,
        update.reserveId,
        update.config.collateralRisk
      );
    }
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function updateDynamicConfigs(
    address spoke,
    address spokeConfigurator,
    DynamicConfigUpdate[] calldata updates
  ) external {
    for (uint256 i; i < updates.length; i++) {
      ISpokeConfigurator(spokeConfigurator).updateDynamicReserveConfig(
        spoke,
        updates[i].reserveId,
        updates[i].dynamicConfigKey,
        updates[i].config
      );
    }
  }
}
