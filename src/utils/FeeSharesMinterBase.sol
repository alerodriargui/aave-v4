// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {Ownable2Step, Ownable} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {Rescuable} from 'src/utils/Rescuable.sol';
import {IFeeSharesMinterBase} from 'src/utils/IFeeSharesMinterBase.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title FeeSharesMinterBase
/// @author Aave Labs
/// @notice Contract to mint fee shares on the Hub when specific conditions are met.
contract FeeSharesMinterBase is IFeeSharesMinterBase, Ownable2Step, Rescuable {
  /// @inheritdoc IFeeSharesMinterBase
  uint256 public constant MAX_TIME_INTERVAL = 365 days;

  /// @inheritdoc IFeeSharesMinterBase
  mapping(address => mapping(uint256 => uint256)) public lastMintTime;

  mapping(address => mapping(uint256 => MintConfig)) internal _configs;

  /// @dev Constructor.
  /// @param owner The owner of the contract.
  constructor(address owner) Ownable(owner) {}

  /// @inheritdoc IFeeSharesMinterBase
  function setConfig(address hub, uint256 assetId, MintConfig memory config) external onlyOwner {
    require(
      config.minUnrealizedFeePercent <= PercentageMath.PERCENTAGE_FACTOR &&
        config.minTimeInterval <= MAX_TIME_INTERVAL,
      InvalidConfig()
    );
    _configs[hub][assetId] = config;
    emit ConfigUpdated(hub, assetId, config);
  }

  /// @inheritdoc IFeeSharesMinterBase
  function execute(address hub, uint256 assetId) external {
    require(_checkExecute(hub, assetId), ConditionsNotMet());

    lastMintTime[hub][assetId] = block.timestamp;
    IHub(hub).mintFeeShares(assetId);
  }

  /// @inheritdoc IFeeSharesMinterBase
  function performUpkeep(bytes calldata performData) external override {
    (address hub, uint256 assetId) = abi.decode(performData, (address, uint256));
    require(_checkExecute(hub, assetId), ConditionsNotMet());

    lastMintTime[hub][assetId] = block.timestamp;
    IHub(hub).mintFeeShares(assetId);
  }

  /// @inheritdoc IFeeSharesMinterBase
  function checkUpkeep(
    bytes calldata checkData
  ) external view override returns (bool upkeepNeeded, bytes memory performData) {
    (address hub, uint256 assetId) = abi.decode(checkData, (address, uint256));
    upkeepNeeded = _checkExecute(hub, assetId);
    performData = checkData;
  }

  /// @inheritdoc IFeeSharesMinterBase
  function getConfig(address hub, uint256 assetId) external view returns (MintConfig memory) {
    return _configs[hub][assetId];
  }

  /// @inheritdoc IFeeSharesMinterBase
  function checkExecute(address hub, uint256 assetId) external view returns (bool) {
    return _checkExecute(hub, assetId);
  }

  /// @dev Internal function to check execution conditions.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return True if conditions are met, false otherwise.
  function _checkExecute(address hub, uint256 assetId) internal view virtual returns (bool) {
    MintConfig memory config = _configs[hub][assetId];

    // Check mint interval
    if (block.timestamp - lastMintTime[hub][assetId] < config.minTimeInterval) {
      return false;
    }

    IHub hubContract = IHub(hub);
    uint256 accruedFees = hubContract.getAssetAccruedFees(assetId);
    uint256 totalAddedAssets = hubContract.getAddedAssets(assetId);

    // Check if accruedFees / totalAddedAssets >= minUnrealizedFeePercent (in bps)
    if (
      PercentageMath.percentDivDown(accruedFees, totalAddedAssets) < config.minUnrealizedFeePercent
    ) {
      return false;
    }

    // Ensure at least 1 fee share would be minted
    uint256 expectedShares = hubContract.previewAddByAssets(assetId, accruedFees);

    return expectedShares > 0;
  }

  /// @inheritdoc Rescuable
  function _rescueGuardian() internal view override returns (address) {
    return owner();
  }
}
