// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4SpokeConfigEngine} from 'src/deployments/config-engine/IAaveV4SpokeConfigEngine.sol';

/// @title AaveV4SpokePayload
/// @author Aave Labs
/// @notice Abstract payload for Spoke-only operations (listing reserves, updating liquidation config).
/// @dev Override the virtual functions to provide listing data. Call execute() to run the payload.
abstract contract AaveV4SpokePayload {
  IAaveV4SpokeConfigEngine public immutable SPOKE_CONFIG_ENGINE;

  constructor(address spokeConfigEngine_) {
    SPOKE_CONFIG_ENGINE = IAaveV4SpokeConfigEngine(spokeConfigEngine_);
  }

  /// @notice Executes the Spoke payload.
  function execute() external {
    _preExecute();

    IAaveV4SpokeConfigEngine.ReserveListing[] memory reserves = newReserveListings();
    if (reserves.length > 0) {
      SPOKE_CONFIG_ENGINE.listReserves(reserves);
    }

    IAaveV4SpokeConfigEngine.LiquidationConfigInput memory liqConfig = liquidationConfig();
    SPOKE_CONFIG_ENGINE.updateLiquidationConfig(liqConfig);

    _postExecute();
  }

  /// @notice Returns the list of reserves to add to the Spoke. Override in concrete payloads.
  function newReserveListings()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.ReserveListing[] memory)
  {
    return new IAaveV4SpokeConfigEngine.ReserveListing[](0);
  }

  /// @notice Returns the liquidation configuration for the Spoke. Override in concrete payloads.
  function liquidationConfig()
    public
    view
    virtual
    returns (IAaveV4SpokeConfigEngine.LiquidationConfigInput memory);

  /// @notice Hook called before the payload execution.
  function _preExecute() internal virtual {}

  /// @notice Hook called after the payload execution.
  function _postExecute() internal virtual {}
}
