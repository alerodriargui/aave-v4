// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {SharesMath} from 'src/hub/libraries/SharesMath.sol';
import {IBasicInterestRateStrategy} from 'src/hub/interfaces/IBasicInterestRateStrategy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title AssetLogic library
/// @author Aave Labs
/// @notice Implements the base logic and share price conversions for asset data.
library AssetLogic {
  using AssetLogic for IHub.Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for *;
  using MathUtils for uint256;
  using SafeCast for uint256;

  struct AssetCache {
    uint256 totalAssets;
    uint256 totalShares;
    uint256 drawnIndex;
    uint256 liquidity;
    uint256 swept;
    uint256 deficit;
    uint256 addedShares;
    uint256 premiumShares;
    uint256 premiumOffset;
    uint256 drawnShares;
    uint256 realizedPremium;
  }

  function clone(IHub.Asset storage asset) internal view returns (AssetCache memory cache) {
    cache.drawnIndex = asset.getDrawnIndex(); // can be split since it reads index, rate, time, {drawn,premium}Shares
    cache.liquidity = asset.liquidity;
    cache.addedShares = asset.addedShares;
    cache.deficit = asset.deficit;
    cache.swept = asset.swept;
    cache.premiumShares = asset.premiumShares;
    cache.premiumOffset = asset.premiumOffset;
    cache.drawnShares = asset.drawnShares;
    cache.realizedPremium = asset.realizedPremium;

    uint256 owed = cache.premiumShares.rayMulUp(cache.drawnIndex) - cache.premiumOffset;
    owed += cache.realizedPremium;
    owed += cache.drawnShares.rayMulUp(cache.drawnIndex);
    cache.totalAssets = cache.liquidity + cache.swept + cache.deficit + owed;
    cache.totalShares = cache.addedShares; // ! todo: add fee shares

    return cache;
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding up.
  function toDrawnAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding down.
  function toDrawnAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding up.
  function toDrawnSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding down.
  function toDrawnSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(asset.getDrawnIndex());
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding up.
  function toDrawnAssetsUp(
    AssetCache memory cache,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulUp(cache.drawnIndex);
  }

  /// @notice Converts an amount of shares to the equivalent amount of drawn assets, rounding down.
  function toDrawnAssetsDown(
    AssetCache memory cache,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.rayMulDown(cache.drawnIndex);
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding up.
  function toDrawnSharesUp(
    AssetCache memory cache,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivUp(cache.drawnIndex);
  }

  /// @notice Converts an amount of drawn assets to the equivalent amount of shares, rounding down.
  function toDrawnSharesDown(
    AssetCache memory cache,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.rayDivDown(cache.drawnIndex);
  }

  /// @notice Returns the total drawn assets amount for the specified asset.
  function drawn(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawnShares.rayMulUp(asset.getDrawnIndex());
  }

  /// @notice Returns the total premium amount for the specified asset.
  function premium(IHub.Asset storage asset) internal view returns (uint256) {
    // sanity: utilize solc underflow check
    uint256 accruedPremium = asset.toDrawnAssetsUp(asset.premiumShares) - asset.premiumOffset;
    return asset.realizedPremium + accruedPremium;
  }

  /// @notice Returns the total amount owed for the specified asset, including drawn and premium.
  function totalOwed(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.drawn() + asset.premium();
  }

  /// @notice Returns the total added assets for the specified asset.
  function totalAddedAssets(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.liquidity + asset.swept + asset.deficit + asset.totalOwed();
  }

  /// @notice Returns the total added shares for the specified asset.
  function totalAddedShares(IHub.Asset storage asset) internal view returns (uint256) {
    return asset.addedShares + asset.unrealizedFeeShares();
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  function toAddedAssetsUp(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  function toAddedAssetsDown(
    IHub.Asset storage asset,
    uint256 shares
  ) internal view returns (uint256) {
    return shares.toAssetsDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  function toAddedSharesUp(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesUp(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  function toAddedSharesDown(
    IHub.Asset storage asset,
    uint256 assets
  ) internal view returns (uint256) {
    return assets.toSharesDown(asset.totalAddedAssets(), asset.totalAddedShares());
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding up.
  function toAddedAssetsUp(
    AssetCache memory cache,
    uint256 shares
  ) internal pure returns (uint256) {
    return shares.toAssetsUp(cache.totalAssets, cache.totalShares);
  }

  /// @notice Converts an amount of shares to the equivalent amount of added assets, rounding down.
  function toAddedAssetsDown(
    AssetCache memory cache,
    uint256 shares
  ) internal pure returns (uint256) {
    return shares.toAssetsDown(cache.totalAssets, cache.totalShares);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding up.
  function toAddedSharesUp(
    AssetCache memory cache,
    uint256 assets
  ) internal pure returns (uint256) {
    return assets.toSharesUp(cache.totalAssets, cache.totalShares);
  }

  /// @notice Converts an amount of added assets to the equivalent amount of shares, rounding down.
  function toAddedSharesDown(
    AssetCache memory cache,
    uint256 assets
  ) internal pure returns (uint256) {
    return assets.toSharesDown(cache.totalAssets, cache.totalShares);
  }

  /// @notice Updates the drawn rate of a specified asset.
  /// @dev Premium debt is not used in the interest rate calculation.
  function updateDrawnRate(
    IHub.Asset storage asset,
    AssetCache memory cache,
    uint256 assetId
  ) internal {
    uint256 newDrawnRate = IBasicInterestRateStrategy(asset.irStrategy).calculateInterestRate({
      assetId: assetId,
      liquidity: cache.liquidity,
      drawn: cache.drawnShares.rayMulUp(cache.drawnIndex),
      deficit: cache.deficit,
      swept: cache.swept
    });
    asset.drawnRate = newDrawnRate.toUint96();

    // asset accrual should have already occurred
    emit IHub.UpdateAsset(assetId, cache.drawnIndex, newDrawnRate);
  }

  /// @notice Accrues interest and fees for the specified asset.
  function accrue(
    IHub.Asset storage asset,
    AssetCache memory cache,
    mapping(uint256 => mapping(address => IHub.SpokeData)) storage spokes,
    uint256 assetId
  ) internal {
    if (asset.lastUpdateTimestamp == block.timestamp) {
      return;
    }

    uint256 newDrawnIndex = cache.drawnIndex;
    uint256 indexDelta = newDrawnIndex.uncheckedSub(asset.drawnIndex);

    asset.drawnIndex = newDrawnIndex.toUint128();
    asset.lastUpdateTimestamp = block.timestamp.toUint32();

    uint128 feeShares = asset.getFeeShares(cache, indexDelta).toUint128();
    if (feeShares > 0) {
      address feeReceiver = asset.feeReceiver;
      asset.addedShares = (cache.addedShares + feeShares).toUint128();
      spokes[assetId][feeReceiver].addedShares += feeShares;
      cache.totalShares += feeShares;
      emit IHub.AccrueFees(assetId, feeReceiver, feeShares);
    }
  }

  /// @notice Calculates the drawn index of a specified asset based on the existing drawn rate and index.
  function getDrawnIndex(IHub.Asset storage asset) internal view returns (uint256) {
    uint256 previousIndex = asset.drawnIndex;
    uint256 lastUpdateTimestamp = asset.lastUpdateTimestamp;
    if (
      lastUpdateTimestamp == block.timestamp || (asset.drawnShares == 0 && asset.premiumShares == 0)
    ) {
      return previousIndex;
    }
    return
      previousIndex.rayMulUp(
        MathUtils.calculateLinearInterest(asset.drawnRate, uint32(lastUpdateTimestamp))
      );
  }

  /// @notice Calculates the amount of fee shares derived from the index growth due to interest accrual.
  /// @dev The true liquidity growth is always greater than accrued fees, even with 100.00% liquidity fee.
  /// @param indexDelta The delta between the current and next drawn index.
  function getFeeShares(
    IHub.Asset storage asset,
    AssetCache memory cache,
    uint256 indexDelta
  ) internal view returns (uint256) {
    if (indexDelta == 0) return 0;
    uint256 liquidityFee = asset.liquidityFee;
    if (liquidityFee == 0) return 0;

    // we do not simplify further to avoid overestimating the liquidity growth
    uint256 feeAmount = (cache.drawnShares.rayMulDown(indexDelta) +
      cache.premiumShares.rayMulDown(indexDelta)).percentMulDown(liquidityFee);

    return feeAmount.toSharesDown(cache.totalAssets - feeAmount, cache.addedShares);
  }

  /// @notice Calculates the amount of unrealized fee shares since last accrual.
  function unrealizedFeeShares(IHub.Asset storage asset) internal view returns (uint256) {
    AssetCache memory cache = asset.clone();
    return asset.getFeeShares(cache, cache.drawnIndex.uncheckedSub(asset.drawnIndex));
  }
}
