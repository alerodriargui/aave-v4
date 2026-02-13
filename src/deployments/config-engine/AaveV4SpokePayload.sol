// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4PayloadBase} from 'src/deployments/config-engine/AaveV4PayloadBase.sol';
import {IAaveV4SpokeConfigEngine} from 'src/deployments/config-engine/IAaveV4SpokeConfigEngine.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title AaveV4SpokePayload
/// @author Aave Labs
/// @notice Abstract payload for Spoke-only operations (listing reserves, updating configs).
/// @dev Uses DELEGATECALL to the stateless SPOKE_CONFIG_ENGINE so that the governance executor's
///      address (which holds the AccessManager roles) is preserved as msg.sender.
///      Override the virtual functions to provide listing/update data.
abstract contract AaveV4SpokePayload is AaveV4PayloadBase {
  IAaveV4SpokeConfigEngine public immutable SPOKE_CONFIG_ENGINE;
  address public immutable SPOKE;
  address public immutable SPOKE_CONFIGURATOR;
  address public immutable HUB;

  constructor(
    address spokeConfigEngine_,
    address spoke_,
    address spokeConfigurator_,
    address hub_
  ) {
    SPOKE_CONFIG_ENGINE = IAaveV4SpokeConfigEngine(spokeConfigEngine_);
    SPOKE = spoke_;
    SPOKE_CONFIGURATOR = spokeConfigurator_;
    HUB = hub_;
  }

  /// @inheritdoc AaveV4PayloadBase
  function _executePayload() internal override {
    // Listings
    IAaveV4SpokeConfigEngine.ReserveListing[] memory reserves = newReserveListings();
    if (reserves.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.listReserves,
          (SPOKE, SPOKE_CONFIGURATOR, HUB, reserves)
        )
      );
    }

    // Liquidation config (only update if non-zero targetHealthFactor indicates intent)
    IAaveV4SpokeConfigEngine.LiquidationConfigInput memory liqConfig = liquidationConfig();
    if (liqConfig.config.targetHealthFactor > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.updateLiquidationConfig,
          (SPOKE, SPOKE_CONFIGURATOR, liqConfig)
        )
      );
    }

    // Reserve updates
    IAaveV4SpokeConfigEngine.ReserveConfigUpdate[] memory reserveUpdates = reserveConfigUpdates();
    if (reserveUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.updateReserves,
          (SPOKE, SPOKE_CONFIGURATOR, reserveUpdates)
        )
      );
    }

    // Dynamic config updates
    IAaveV4SpokeConfigEngine.DynamicConfigUpdate[] memory dynamicUpdates = dynamicConfigUpdates();
    if (dynamicUpdates.length > 0) {
      _delegateToEngine(
        abi.encodeCall(
          IAaveV4SpokeConfigEngine.updateDynamicConfigs,
          (SPOKE, SPOKE_CONFIGURATOR, dynamicUpdates)
        )
      );
    }
  }

  // ==================== Listing Hooks ====================

  function newReserveListings()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.ReserveListing[] memory)
  {
    return new IAaveV4SpokeConfigEngine.ReserveListing[](0);
  }

  function liquidationConfig()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.LiquidationConfigInput memory)
  {
    return
      IAaveV4SpokeConfigEngine.LiquidationConfigInput({config: ISpoke.LiquidationConfig(0, 0, 0)});
  }

  // ==================== Update Hooks ====================

  function reserveConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.ReserveConfigUpdate[] memory)
  {
    return new IAaveV4SpokeConfigEngine.ReserveConfigUpdate[](0);
  }

  function dynamicConfigUpdates()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.DynamicConfigUpdate[] memory)
  {
    return new IAaveV4SpokeConfigEngine.DynamicConfigUpdate[](0);
  }

  // ==================== Internal ====================

  /// @dev DELEGATECALLs to the stateless config engine, preserving msg.sender context.
  function _delegateToEngine(bytes memory data) internal {
    (bool success, bytes memory returnData) = address(SPOKE_CONFIG_ENGINE).delegatecall(data);
    if (!success) {
      assembly {
        revert(add(returnData, 32), mload(returnData))
      }
    }
  }
}
