// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WadRayMathExtended} from 'src/libraries/math/WadRayMathExtended.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {SharesMath} from 'src/libraries/math/SharesMath.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {PercentageMathExtended} from 'src/libraries/math/PercentageMathExtended.sol';

library AssetLogic {
  using AssetLogic for DataTypes.Asset;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;

  // todo: option for cached object
  // todo: add virtual offset for inflation attack

  // debt exchange rate does not incl premiumDebt to accrue base rate separately
  function toDrawnAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    (uint256 drawnIndex, ) = asset.previewIndex();
    return shares.rayMulUp(drawnIndex);
  }
  function toDrawnAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    (uint256 drawnIndex, ) = asset.previewIndex();
    return shares.rayMulDown(drawnIndex);
  }

  function toDrawnSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    (uint256 drawnIndex, ) = asset.previewIndex();
    return assets.rayDivUp(drawnIndex);
  }
  function toDrawnSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    (uint256 drawnIndex, ) = asset.previewIndex();
    return assets.rayDivDown(drawnIndex);
  }

  function baseDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    (uint256 drawnIndex, ) = asset.previewIndex();
    return asset.baseDrawnShares.rayMulUp(drawnIndex);
  }

  function premiumDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumDrawnShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }

  function debt(DataTypes.Asset storage asset) internal view returns (uint256, uint256) {
    return (asset.baseDebt(), asset.premiumDebt());
  }

  function totalDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDebt() + asset.premiumDebt();
  }

  function totalSuppliedAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.availableLiquidity + asset.totalDebt();
  }

  function totalSuppliedShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.suppliedShares;
  }

  function toSuppliedAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  function toSuppliedAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  function toSuppliedSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }
  function toSuppliedSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalSuppliedAssets(), asset.totalSuppliedShares());
  }

  // risk premium interest rate is calculated offchain
  function baseInterestRate(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseBorrowRate;
  }

  function updateBorrowRate(
    DataTypes.Asset storage asset,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    asset.baseBorrowRate = asset.config.irStrategy.calculateInterestRates(
      DataTypes.CalculateInterestRatesParams({
        liquidityAdded: liquidityAdded,
        liquidityTaken: liquidityTaken,
        totalDebt: asset.baseDebt(),
        reserveFactor: 0, // TODO
        assetId: asset.id,
        virtualUnderlyingBalance: asset.availableLiquidity, // without current liquidity change
        usingVirtualBalance: true
      })
    );
  }

  // @dev Utilizes existing `asset.baseBorrowRate`
  function accrue(DataTypes.Asset storage asset) internal {
    (uint256 drawnIndex, uint256 feesIndex) = asset.previewIndex();
    asset.baseDebtIndex = drawnIndex;
    asset.feesIndex += feesIndex;
    asset.lastUpdateTimestamp = block.timestamp;
  }

  /// @return the new drawn index
  /// @return the treasury fees index
  function previewIndex(DataTypes.Asset storage asset) internal view returns (uint256, uint256) {
    uint256 previousIndex = asset.baseDebtIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (lastUpdateTimestamp == block.timestamp || asset.baseDrawnShares == 0) {
      return (previousIndex, 0);
    }
    uint256 newIndex = previousIndex.rayMulUp(
      MathUtils.calculateLinearInterest(asset.baseBorrowRate, uint40(lastUpdateTimestamp))
    );
    uint256 feesIndex = newIndex;
    uint256 reserveFactor = asset.config.reserveFactor;
    if (reserveFactor > 0) {
      feesIndex = newIndex.percentMulDown(PercentageMath.PERCENTAGE_FACTOR);
    }
    return (newIndex, feesIndex);
  }
}
