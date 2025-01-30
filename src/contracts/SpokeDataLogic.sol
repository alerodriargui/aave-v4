pragma solidity ^0.8.0;

import {SpokeData, SpokeDataCache} from 'src/contracts/LiquidityHub.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';

library SpokeDataLogic {
  using SpokeDataLogic for SpokeData;
  using SpokeDataLogic for SpokeDataCache;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // @dev Utilizes existing `spoke.baseBorrowIndex` & `spoke.riskPremiumRad`
  function accrueInterest(
    SpokeData storage spoke,
    SpokeDataCache memory spokeCache,
    uint256 nextBaseBorrowIndex
  ) internal {
    uint256 elapsed = block.timestamp - spoke.lastUpdateTimestamp;
    if (elapsed == 0) return;
    uint256 existingBaseDebt = spokeCache.existingBaseDebt;
    if (existingBaseDebt == 0) return;

    // todo: add rayMulDiv in WadRayMath (=mulDiv / RAY) to optimize out the one cancelled RAY
    // & avoid precision loss, cache index ratio for rp update
    uint256 cumulatedBaseDebt = existingBaseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      spoke.baseBorrowIndex
    );

    spoke.outstandingPremium += spokeCache.existingRiskPremiumRay().rayMul(
      cumulatedBaseDebt - existingBaseDebt
    );
    spoke.baseDebt = spokeCache.cumulatedBaseDebt = cumulatedBaseDebt;
    spoke.baseBorrowIndex = nextBaseBorrowIndex;
    spoke.lastUpdateTimestamp = block.timestamp;

    spoke.riskPremiumWeightedSum = spokeCache.cumulatedRiskPremiumWeightedSum = spokeCache
      .existingRiskPremiumWeightedSum
      .rayMul(nextBaseBorrowIndex)
      .rayDiv(spoke.baseBorrowIndex);
  }

  function riskPremiumRay(SpokeData storage spoke) internal view returns (uint256) {
    // todo use mulDiv
    return spoke.baseDebt == 0 ? 0 : spoke.riskPremiumWeightedSum.toRay() / spoke.baseDebt;
  }

  function existingRiskPremiumRay(SpokeDataCache memory cache) internal view returns (uint256) {
    return
      cache.existingBaseDebt == 0
        ? 0
        : cache.existingRiskPremiumWeightedSum.toRay() / cache.existingBaseDebt;
  }

  function cache(SpokeData storage spoke) internal view returns (SpokeDataCache memory) {
    SpokeDataCache memory cache;
    cache.existingBaseDebt = cache.cumulatedBaseDebt = spoke.baseDebt;
    cache.existingRiskPremiumWeightedSum = cache.cumulatedRiskPremiumWeightedSum = spoke
      .riskPremiumWeightedSum;
    return cache;
  }
}
