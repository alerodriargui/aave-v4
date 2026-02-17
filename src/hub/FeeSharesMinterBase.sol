// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';

/**
 * @title FeeSharesMinterBase
 * @notice Contract to mint fee shares on the Hub when specific conditions are met.
 */
contract FeeSharesMinterBase is Ownable {
  struct MintConfig {
    uint256 minTimeInterval;
    uint256 minUnrealizedFeePercent; // 1e4 = 100% (basis points)
  }

  IHub public immutable HUB;

  mapping(uint256 => MintConfig) internal _configs;
  mapping(uint256 => uint256) public lastMintTime;

  event ConfigUpdated(uint256 indexed assetId, MintConfig config);
  event FeeSharesMinted(uint256 indexed assetId, uint256 shares);

  error ConditionsNotMet();

  constructor(address owner, IHub hub) Ownable(owner) {
    HUB = hub;
  }

  /**
   * @notice Sets the automation configuration for a specific asset.
   * @param assetId The identifier of the asset.
   * @param config The new configuration.
   */
  function setConfig(uint256 assetId, MintConfig memory config) external onlyOwner {
    _configs[assetId] = config;
    emit ConfigUpdated(assetId, config);
  }

  /**
   * @notice Executes the fee minting if conditions are met.
   * @param assetId The identifier of the asset.
   */
  function execute(uint256 assetId) external {
    if (!_checkExecute(assetId)) {
      revert ConditionsNotMet();
    }

    lastMintTime[assetId] = block.timestamp;

    uint256 shares = HUB.mintFeeShares(assetId);
    emit FeeSharesMinted(assetId, shares);
  }

  /**
   * @notice Returns the automation configuration for a specific asset.
   * @param assetId The identifier of the asset.
   * @return The configuration struct.
   */
  function getConfig(uint256 assetId) external view returns (MintConfig memory) {
    return _configs[assetId];
  }

  /**
   * @notice Checks if the conditions to mint fee shares are met.
   * @param assetId The identifier of the asset.
   * @return True if conditions are met, false otherwise.
   */
  function checkExecute(uint256 assetId) external view returns (bool) {
    return _checkExecute(assetId);
  }

  /**
   * @dev Internal function to check execution conditions.
   * @param assetId The identifier of the asset.
   * @return True if conditions are met, false otherwise.
   */
  function _checkExecute(uint256 assetId) internal view returns (bool) {
    MintConfig memory config = _configs[assetId];

    // Check mint interval
    if (block.timestamp - lastMintTime[assetId] < config.minTimeInterval) {
      return false;
    }

    uint256 accruedFees = HUB.getAssetAccruedFees(assetId);

    uint256 totalAddedAssets = HUB.getAddedAssets(assetId);
    if (totalAddedAssets == 0) return false;

    // Check if accruedFees / totalAddedAssets >= minUnrealizedFeePercent (in bps)
    if ((accruedFees * 10000) / totalAddedAssets < config.minUnrealizedFeePercent) {
      return false;
    }

    // Ensure at least 1 fee share is minted
    uint256 expectedShares = HUB.previewAddByAssets(assetId, accruedFees);
    if (expectedShares < 1) {
      return false;
    }

    return true;
  }
}
