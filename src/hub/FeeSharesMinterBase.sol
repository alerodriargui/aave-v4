// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';

/// @title FeeSharesMinterBase
/// @author Aave Labs
/// @notice Contract to mint fee shares on the Hub when specific conditions are met.
contract FeeSharesMinterBase is Ownable {
  struct MintConfig {
    uint256 minTimeInterval;
    uint256 minUnrealizedFeePercent; // 1e4 = 100% (basis points)
  }

  mapping(address => mapping(uint256 => MintConfig)) internal _configs;
  mapping(address => mapping(uint256 => uint256)) public lastMintTime;

  event ConfigUpdated(address indexed hub, uint256 indexed assetId, MintConfig config);

  error ConditionsNotMet();

  /// @dev Constructor.
  /// @param owner The owner of the contract.
  constructor(address owner) Ownable(owner) {}

  /// @notice Sets the automation configuration for a specific asset.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @param config The new configuration.
  function setConfig(address hub, uint256 assetId, MintConfig memory config) external onlyOwner {
    _configs[hub][assetId] = config;
    emit ConfigUpdated(hub, assetId, config);
  }

  /// @notice Executes the fee minting if conditions are met.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  function execute(address hub, uint256 assetId) external {
    if (!_checkExecute(hub, assetId)) {
      revert ConditionsNotMet();
    }

    lastMintTime[hub][assetId] = block.timestamp;
    IHub(hub).mintFeeShares(assetId);
  }

  /// @notice Returns the automation configuration for a specific asset.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return The configuration struct.
  function getConfig(address hub, uint256 assetId) external view returns (MintConfig memory) {
    return _configs[hub][assetId];
  }

  /// @notice Checks if the conditions to mint fee shares are met.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return True if conditions are met, false otherwise.
  function checkExecute(address hub, uint256 assetId) external view returns (bool) {
    return _checkExecute(hub, assetId);
  }

  /// @dev Internal function to check execution conditions.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return True if conditions are met, false otherwise.
  function _checkExecute(address hub, uint256 assetId) internal view returns (bool) {
    MintConfig memory config = _configs[hub][assetId];

    // Check mint interval
    if (block.timestamp - lastMintTime[hub][assetId] < config.minTimeInterval) {
      return false;
    }

    IHub hubContract = IHub(hub);
    uint256 accruedFees = hubContract.getAssetAccruedFees(assetId);

    uint256 totalAddedAssets = hubContract.getAddedAssets(assetId);
    if (totalAddedAssets == 0) return false;

    // Check if accruedFees / totalAddedAssets >= minUnrealizedFeePercent (in bps)
    if ((accruedFees * 10000) / totalAddedAssets < config.minUnrealizedFeePercent) {
      return false;
    }

    // Ensure at least 1 fee share is minted
    uint256 expectedShares = hubContract.previewAddByAssets(assetId, accruedFees);
    if (expectedShares < 1) {
      return false;
    }

    return true;
  }
}
