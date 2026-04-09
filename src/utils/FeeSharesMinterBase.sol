// SPDX-License-Identifier: LicenseRef-BUSL
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
  mapping(address hub => mapping(uint256 assetId => uint16 minAccruedFeesPercent))
    internal _configs;

  /// @dev Constructor.
  /// @param owner The owner of the contract.
  constructor(address owner) Ownable(owner) {}

  /// @inheritdoc IFeeSharesMinterBase
  function setConfig(
    address hub,
    uint256 assetId,
    uint16 minAccruedFeesPercent
  ) external onlyOwner {
    require(minAccruedFeesPercent <= PercentageMath.PERCENTAGE_FACTOR, InvalidConfig());
    _configs[hub][assetId] = minAccruedFeesPercent;
    emit ConfigUpdated(hub, assetId, minAccruedFeesPercent);
  }

  /// @inheritdoc IFeeSharesMinterBase
  function performUpkeep(bytes calldata performData) external override {
    (address hub, uint256 assetId) = abi.decode(performData, (address, uint256));
    _performUpkeep(hub, assetId);
  }

  /// @inheritdoc IFeeSharesMinterBase
  function checkUpkeep(
    bytes calldata checkData
  ) external view override returns (bool, bytes memory) {
    (address hub, uint256 assetId) = abi.decode(checkData, (address, uint256));
    bool upkeepNeeded = _checkUpkeep(hub, assetId);
    bytes memory performData = checkData;
    return (upkeepNeeded, performData);
  }

  /// @inheritdoc IFeeSharesMinterBase
  function getConfig(address hub, uint256 assetId) external view returns (uint16) {
    return _configs[hub][assetId];
  }

  /// @dev Internal function to execute fee share minting.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  function _performUpkeep(address hub, uint256 assetId) internal virtual {
    require(_checkUpkeep(hub, assetId), ConditionsNotMet());

    IHub(hub).mintFeeShares(assetId);
  }

  /// @dev Internal function to check execution conditions.
  /// @param hub The address of the hub.
  /// @param assetId The identifier of the asset.
  /// @return True if conditions are met, false otherwise.
  function _checkUpkeep(address hub, uint256 assetId) internal view virtual returns (bool) {
    uint16 minAccruedFeesPercent = _configs[hub][assetId];

    IHub hubContract = IHub(hub);
    uint256 accruedFees = hubContract.getAssetAccruedFees(assetId);
    uint256 totalAddedAssets = hubContract.getAddedAssets(assetId);

    if (PercentageMath.percentDivDown(accruedFees, totalAddedAssets) < minAccruedFeesPercent) {
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
