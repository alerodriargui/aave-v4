pragma solidity ^0.8.0;

import {IReserveInterestRateStrategy} from 'src/interfaces/IReserveInterestRateStrategy.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {MathUtils} from 'src/contracts/MathUtils.sol';
import {Asset, AssetCache} from 'src/contracts/LiquidityHub.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library AssetLogic {
  using AssetLogic for Asset;
  using AssetLogic for AssetCache;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // todo add remaining: accrue interest, previewNextBorrowIndex, validate*

  // todo: option for cached object

  function totalAssets(Asset storage asset) internal view returns (uint256) {
    return asset.availableLiquidity + asset.outstandingPremium + asset.baseDebt;
  }

  function totalShares(Asset storage asset) internal view returns (uint256) {
    return asset.suppliedShares;
  }

  function riskPremiumRay(Asset storage asset) internal view returns (uint256) {
    // todo use mulDiv or use wad
    return asset.baseDebt == 0 ? 0 : asset.riskPremiumWeightedSum.toRay() / asset.baseDebt;
  }

  function existingRiskPremiumRay(AssetCache memory cache) internal view returns (uint256) {
    return
      cache.existingBaseDebt == 0
        ? 0
        : cache.existingRiskPremiumWeightedSum.toRay() / cache.existingBaseDebt;
  }

  function cache(Asset storage asset) internal view returns (AssetCache memory) {
    AssetCache memory cache;
    cache.existingBaseDebt = cache.cumulatedBaseDebt = asset.baseDebt;
    cache.existingRiskPremiumWeightedSum = cache.cumulatedRiskPremiumWeightedSum = asset
      .riskPremiumWeightedSum;
    return cache;
  }

  // @dev So solc doesn't inline
  function getTotalAssets(Asset storage asset) internal view returns (uint256) {
    return asset.totalAssets();
  }

  function convertToSharesUp(Asset storage asset, uint256 assets) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToSharesDown(
    Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsUp(Asset storage asset, uint256 shares) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsDown(
    Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAssets(), asset.totalShares());
  }

  function getInterestRate(Asset storage asset) internal view returns (uint256) {
    return asset.baseBorrowRate.radMul(WadRayMath.RAD + asset.riskPremiumWeightedSum);
  }

  function updateBorrowRate(
    Asset storage asset,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    uint256 baseBorrowRate = IReserveInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: asset.baseDebt,
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.availableLiquidity, // without current liquidity change
          usingVirtualBalance: true
        })
      );
    asset.baseBorrowRate = baseBorrowRate;
  }

  // @dev Utilizes existing `asset.baseBorrowRate` & `asset.baseBorrowIndex`
  // @return cumulatedBaseInterest (in ray)
  // @return nextBaseBorrowIndex (in ray)
  function previewNextBorrowIndex(Asset storage asset) internal view returns (uint256, uint256) {
    uint256 elapsed = block.timestamp - asset.lastUpdateTimestamp;
    if (elapsed == 0) return (0, asset.baseBorrowIndex);

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      asset.baseBorrowRate,
      uint40(asset.lastUpdateTimestamp)
    );
    return (cumulatedBaseInterest, cumulatedBaseInterest.rayMul(asset.baseBorrowIndex));
  }

  // @dev Utilizes existing `asset.baseBorrowIndex` & `asset.riskPremiumWeightedSum`
  function accrueInterest(
    Asset storage asset,
    AssetCache memory assetCache,
    uint256 cumulatedBaseInterest,
    uint256 nextBaseBorrowIndex
  ) internal {
    if (cumulatedBaseInterest == 0) return; // no interest accrued since last update

    uint256 existingBaseDebt = assetCache.existingBaseDebt;
    // no interest to accrue since no liquidity has been drawn
    if (existingBaseDebt == 0) return;

    // can use `cumulatedBaseInterest` instead of `indexRatio` since LH base debt is
    // accrued on each index update
    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(cumulatedBaseInterest);

    // accrue premium interest on the accrued base interest
    asset.outstandingPremium += assetCache.existingRiskPremiumRay().rayMul(
      cumulatedBaseDebt - existingBaseDebt
    );
    asset.baseDebt = assetCache.cumulatedBaseDebt = cumulatedBaseDebt;
    asset.baseBorrowIndex = nextBaseBorrowIndex;
    asset.lastUpdateTimestamp = block.timestamp;
    asset.riskPremiumWeightedSum = assetCache.cumulatedRiskPremiumWeightedSum = assetCache
      .existingRiskPremiumWeightedSum
      .rayMul(cumulatedBaseInterest);
  }
}
