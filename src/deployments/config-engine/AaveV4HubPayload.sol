// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4HubConfigEngine} from 'src/deployments/config-engine/IAaveV4HubConfigEngine.sol';

/// @title AaveV4HubPayload
/// @author Aave Labs
/// @notice Abstract payload for Hub-only operations (listing assets, registering spokes).
/// @dev Override the virtual functions to provide listing data. Call execute() to run the payload.
abstract contract AaveV4HubPayload {
  IAaveV4HubConfigEngine public immutable HUB_CONFIG_ENGINE;

  constructor(address hubConfigEngine_) {
    HUB_CONFIG_ENGINE = IAaveV4HubConfigEngine(hubConfigEngine_);
  }

  /// @notice Executes the Hub payload in order: assets → spokes.
  function execute() external {
    _preExecute();

    IAaveV4HubConfigEngine.AssetListing[] memory assets = newAssetListings();
    if (assets.length > 0) {
      HUB_CONFIG_ENGINE.listAssets(assets);
    }

    IAaveV4HubConfigEngine.SpokeListing[] memory spokes = newSpokeListings();
    if (spokes.length > 0) {
      HUB_CONFIG_ENGINE.addSpokes(spokes);
    }

    _postExecute();
  }

  /// @notice Returns the list of new assets to add to the Hub. Override in concrete payloads.
  function newAssetListings()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.AssetListing[] memory)
  {
    return new IAaveV4HubConfigEngine.AssetListing[](0);
  }

  /// @notice Returns the list of spokes to register on the Hub. Override in concrete payloads.
  function newSpokeListings()
    public
    view
    virtual
    returns (IAaveV4HubConfigEngine.SpokeListing[] memory)
  {
    return new IAaveV4HubConfigEngine.SpokeListing[](0);
  }

  /// @notice Hook called before the payload execution.
  function _preExecute() internal virtual {}

  /// @notice Hook called after the payload execution.
  function _postExecute() internal virtual {}
}
