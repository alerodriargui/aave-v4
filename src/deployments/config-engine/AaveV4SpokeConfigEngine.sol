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
contract AaveV4SpokeConfigEngine is IAaveV4SpokeConfigEngine {
  address public immutable SPOKE;
  address public immutable SPOKE_CONFIGURATOR;
  address public immutable HUB;

  constructor(address spoke_, address spokeConfigurator_, address hub_) {
    require(spoke_ != address(0), 'invalid spoke');
    require(spokeConfigurator_ != address(0), 'invalid spoke configurator');
    require(hub_ != address(0), 'invalid hub');
    SPOKE = spoke_;
    SPOKE_CONFIGURATOR = spokeConfigurator_;
    HUB = hub_;
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function listReserves(
    ReserveListing[] calldata reserves
  ) external returns (uint256[] memory reserveIds) {
    uint256 len = reserves.length;
    reserveIds = new uint256[](len);

    for (uint256 i; i < len; i++) {
      ReserveListing calldata reserve = reserves[i];

      // Resolve assetId from underlying address
      uint256 assetId = IHub(HUB).getAssetId(reserve.underlying);

      reserveIds[i] = ISpokeConfigurator(SPOKE_CONFIGURATOR).addReserve(
        SPOKE,
        HUB,
        assetId,
        reserve.priceFeed,
        reserve.config,
        reserve.dynamicConfig
      );
    }
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function updateLiquidationConfig(LiquidationConfigInput calldata input) external {
    ISpokeConfigurator(SPOKE_CONFIGURATOR).updateLiquidationConfig(SPOKE, input.config);
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function updateReserves(ReserveConfigUpdate[] calldata updates) external {
    for (uint256 i; i < updates.length; i++) {
      ReserveConfigUpdate calldata update = updates[i];
      if (update.config.paused) {
        ISpokeConfigurator(SPOKE_CONFIGURATOR).updatePaused(SPOKE, update.reserveId, true);
      }
      if (update.config.frozen) {
        ISpokeConfigurator(SPOKE_CONFIGURATOR).updateFrozen(SPOKE, update.reserveId, true);
      }
      ISpokeConfigurator(SPOKE_CONFIGURATOR).updateBorrowable(
        SPOKE,
        update.reserveId,
        update.config.borrowable
      );
      ISpokeConfigurator(SPOKE_CONFIGURATOR).updateReceiveSharesEnabled(
        SPOKE,
        update.reserveId,
        update.config.receiveSharesEnabled
      );
      ISpokeConfigurator(SPOKE_CONFIGURATOR).updateCollateralRisk(
        SPOKE,
        update.reserveId,
        update.config.collateralRisk
      );
    }
  }

  /// @inheritdoc IAaveV4SpokeConfigEngine
  function updateDynamicConfigs(DynamicConfigUpdate[] calldata updates) external {
    for (uint256 i; i < updates.length; i++) {
      ISpokeConfigurator(SPOKE_CONFIGURATOR).updateDynamicReserveConfig(
        SPOKE,
        updates[i].reserveId,
        updates[i].dynamicConfigKey,
        updates[i].config
      );
    }
  }
}
