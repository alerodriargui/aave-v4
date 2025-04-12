// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DataTypes} from 'src/libraries/types/DataTypes.sol';

import {MathUtils} from 'src/contracts/MathUtils.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {Math} from 'src/dependencies/openzeppelin/Math.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library AssetLogic {
  using AssetLogic for DataTypes.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using Math for uint256;

  // todo: option for cached object

  // todo: add virtual offset for inflation attack
  // only include base drawn assets
  function totalDrawnAssets(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDebt();
  }

  function totalDrawnShares(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDrawnShares;
  }

  // total drawn assets does not incl totalOutstandingPremium to accrue base rate separately
  function toDrawnAssetsUp(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.mulDiv(asset.previewIndex(), WadRayMath.RAY, Math.Rounding.Ceil);
  }
  function toDrawnAssetsDown(
    DataTypes.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.mulDiv(asset.previewIndex(), WadRayMath.RAY, Math.Rounding.Floor);
  }

  function toDrawnSharesUp(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.mulDiv(WadRayMath.RAY, asset.previewIndex(), Math.Rounding.Ceil);
  }
  function toDrawnSharesDown(
    DataTypes.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.mulDiv(WadRayMath.RAY, asset.previewIndex(), Math.Rounding.Floor);
  }

  function premiumDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    return
      asset.realizedPremium +
      (asset.toDrawnAssetsUp(asset.premiumDrawnShares) - asset.premiumOffset);
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

  // expects accrued `baseDebt`
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
    asset.baseDebtIndex = asset.previewIndex();
    asset.lastUpdateTimestamp = block.timestamp;
  }

  function previewIndex(DataTypes.Asset storage asset) internal view returns (uint256) {
    uint256 baseDebtIndex = asset.baseDebtIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (lastUpdateTimestamp == block.timestamp) {
      return baseDebtIndex;
    }
    return
      baseDebtIndex.rayMul(
        MathUtils.calculateLinearInterest(asset.baseBorrowRate, uint40(lastUpdateTimestamp))
      );
  }

  function baseDebt(DataTypes.Asset storage asset) internal view returns (uint256) {
    return asset.baseDrawnShares.rayMul(asset.previewIndex());
  }
}
