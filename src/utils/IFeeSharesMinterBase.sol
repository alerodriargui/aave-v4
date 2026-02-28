// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {AutomationCompatibleInterface} from 'src/dependencies/chainlink/AutomationCompatibleInterface.sol';

/// @title IFeeSharesMinterBase
/// @author Aave Labs
/// @notice Interface for the FeeSharesMinterBase contract
interface IFeeSharesMinterBase is AutomationCompatibleInterface {
  /// @notice Configuration for automated fee share minting on a specific asset.
  /// @param minTimeInterval Minimum number of seconds that must elapse between mint executions.
  /// @param minUnrealizedFeePercent Minimum ratio of accrued fees to total assets, in bps.
  struct MintConfig {
    uint48 minTimeInterval;
    uint16 minUnrealizedFeePercent;
  }

  /// @notice Emitted when the mint configuration for an asset is updated.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @param config The new configuration.
  event ConfigUpdated(address indexed hub, uint256 indexed assetId, MintConfig config);

  /// @notice Thrown upon minting when the required conditions are not met.
  error ConditionsNotMet();

  /// @notice Thrown when `setConfig` is called with invalid parameter values.
  error InvalidConfig();

  /// @notice Sets the automation configuration for a specific asset.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @param config The new configuration to apply.
  function setConfig(address hub, uint256 assetId, MintConfig memory config) external;

  /// @notice Executes fee share minting if all conditions are met.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  function execute(address hub, uint256 assetId) external;

  /// @notice Chainlink Automation on-chain execution entry point.
  /// @dev performData must be abi.encoded as (address hub, uint256 assetId).
  /// @inheritdoc AutomationCompatibleInterface
  function performUpkeep(bytes calldata performData) external;

  /// @notice Chainlink Automation off-chain simulation check.
  /// @dev checkData must be abi.encoded as (address hub, uint256 assetId).
  /// @dev Returns upkeepNeeded=true and the same bytes as performData when conditions are met.
  /// @inheritdoc AutomationCompatibleInterface
  function checkUpkeep(
    bytes calldata checkData
  ) external view returns (bool upkeepNeeded, bytes memory performData);

  /// @notice Returns the current automation configuration for a specific asset.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return The stored `MintConfig` struct.
  function getConfig(address hub, uint256 assetId) external view returns (MintConfig memory);

  /// @notice Returns the last timestamp at which fee shares were minted for a given asset.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return The block timestamp of the last successful `execute` call.
  function lastMintTime(address hub, uint256 assetId) external view returns (uint256);

  /// @notice Checks whether the conditions to mint fee shares are currently met.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return True if `execute` would succeed, false otherwise.
  function checkExecute(address hub, uint256 assetId) external view returns (bool);

  /// @notice The maximum allowed value for enforcing the elapsed time between mint executions.
  function MAX_TIME_INTERVAL() external view returns (uint256);
}
