// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title IHubEngine
/// @author Aave Labs
/// @notice Interface for the Hub Engine contract.
interface IHubEngine {
  function executeHubAssetListings(IAaveV4ConfigEngine.AssetListing[] calldata listings) external;
  function executeHubAssetConfigUpdates(
    IAaveV4ConfigEngine.AssetConfigUpdate[] calldata updates
  ) external;
  function executeHubSpokeToAssetsAdditions(
    IAaveV4ConfigEngine.SpokeToAssetsAddition[] calldata additions
  ) external;
  function executeHubSpokeConfigUpdates(
    IAaveV4ConfigEngine.SpokeConfigUpdate[] calldata updates
  ) external;
  function executeHubAssetHalts(IAaveV4ConfigEngine.AssetHalt[] calldata halts) external;
  function executeHubAssetDeactivations(
    IAaveV4ConfigEngine.AssetDeactivation[] calldata deactivations
  ) external;
  function executeHubAssetCapsResets(IAaveV4ConfigEngine.AssetCapsReset[] calldata resets) external;
  function executeHubSpokeHalts(IAaveV4ConfigEngine.SpokeHalt[] calldata halts) external;
  function executeHubSpokeDeactivations(
    IAaveV4ConfigEngine.SpokeDeactivation[] calldata deactivations
  ) external;
  function executeHubSpokeCapsResets(IAaveV4ConfigEngine.SpokeCapsReset[] calldata resets) external;
}
