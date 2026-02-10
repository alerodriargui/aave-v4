// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeAccrueLiquidityFeeEdgeCasesTest is SpokeBase {
  using WadRayMath for uint256;
  using PercentageMath for uint256;
  using SafeCast for *;

  uint256 public constant MAX_LIQUIDITY_FEE = 100_00;

  /// @dev Max liquidity fee with premium debt accrual
  function test_accrueLiquidityFee_maxLiquidityFee_with_premium() public {
    test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium({
      reserveId: _daiReserveId(spoke1),
      borrowAmount: 500e18,
      skipTime: 400 days,
      rate: 50_00
    });
  }

  /// @dev Fuzz - max liquidity fee with premium debt accrual
  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium(
    uint256 reserveId,
    uint256 borrowAmount,
    uint256 skipTime,
    uint256 rate
  ) public {
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);

    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    borrowAmount = bound(borrowAmount, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 2); // within collateralization

    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(skipTime);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    (, uint256 premiumDebt) = spoke1.getUserDebt(reserveId, alice);
    assertGt(premiumDebt, 0);

    assertApproxEqAbs(
      spoke1.getUserSuppliedAssets(reserveId, alice),
      supplyAmount,
      3,
      'alice does not earn anything'
    );
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      spoke1.getUserTotalDebt(reserveId, alice) - borrowAmount,
      3,
      'fees == total user accrued'
    );
    assertApproxEqAbs(
      hub1.getSpokeAddedAssets(assetId, address(treasurySpoke)),
      hub1.getSpokeTotalOwed(assetId, address(spoke1)) - borrowAmount,
      3,
      'fees == total spoke accrued'
    );
  }

  /// @dev Fuzz - max liquidity fee with premium debt accrual for multiple users
  function test_accrueLiquidityFee_fuzz_maxLiquidityFee_with_premium_multiple_users(
    uint256 reserveId,
    uint256 borrowAmount,
    uint256 borrowAmount2,
    uint256 skipTime,
    uint256 rate
  ) public {
    rate = bound(rate, 1, MAX_BORROW_RATE);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    reserveId = bound(reserveId, 0, spoke1.getReserveCount() - 1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    borrowAmount = bound(borrowAmount, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 4); // within collateralization
    borrowAmount2 = bound(borrowAmount2, 1, _calculateMaxSupplyAmount(spoke1, reserveId) / 4); // within collateralization

    updateLiquidityFee(hub1, spoke1.getReserve(reserveId).assetId, MAX_LIQUIDITY_FEE);

    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 supplyAmount2 = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount2);
    _mockInterestRateBps(rate);

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount2, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount2, bob);

    skip(skipTime);
    Utils.mintFeeShares(hub1, assetId, ADMIN);

    assertApproxEqAbs(
      spoke1.getUserSuppliedAssets(reserveId, alice),
      supplyAmount,
      3,
      'alice does not earn anything'
    );
    assertApproxEqAbs(
      spoke1.getUserSuppliedAssets(reserveId, bob),
      supplyAmount2,
      3,
      'bob does not earn anything'
    );

    uint256 totalAccruedToTreasury = hub1.getSpokeAddedAssets(assetId, address(treasurySpoke));
    assertLe(
      totalAccruedToTreasury,
      spoke1.getUserTotalDebt(reserveId, alice) -
        borrowAmount +
        spoke1.getUserTotalDebt(reserveId, bob) -
        borrowAmount2,
      'treasury accrued <= total accrued'
    );
    assertApproxEqAbs(
      totalAccruedToTreasury,
      hub1.getSpokeTotalOwed(assetId, address(spoke1)) - borrowAmount - borrowAmount2,
      3,
      'fees == total spoke accrued'
    );
  }

  function test_accrueLiquidityFee_maxLiquidityFee_multi_user() public {
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;
    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);

    uint256 count = vm.randomUint(10, 1000);
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i);
      uint256 borrowAmount = vm.randomUint(1, _calculateMaxSupplyAmount(spoke1, reserveId) / count);
      _backedBorrow(spoke1, user, reserveId, reserveId, borrowAmount);
    }
    uint256 totalOwedBefore = hub1.getAssetTotalOwed(assetId);

    skip(vm.randomUint(1, MAX_SKIP_TIME));

    uint256 feesAccrued;
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i); // deterministic operation
      uint256 totalOwedAfter = hub1.getAssetTotalOwed(assetId);
      Utils.repay(spoke1, reserveId, user, 1, user); // accrue interest & realize premium
      assertApproxEqAbs(totalOwedAfter, hub1.getAssetTotalOwed(assetId), 1);

      feesAccrued += totalOwedAfter - totalOwedBefore;
      totalOwedBefore = hub1.getAssetTotalOwed(assetId);

      uint256 actualFeesAccrued = _getExpectedFeeReceiverAddedAssets(hub1, assetId);
      assertApproxEqRel(actualFeesAccrued, feesAccrued, 0.0000001e18); // 0.00001%
      assertLe(actualFeesAccrued, feesAccrued, 'actual fees <= expected fees');

      skip(vm.randomUint(0, MAX_SKIP_TIME / count));
    }
  }

  function test_accrueLiquidityFee_maxLiquidityFee_multi_spoke() public {
    uint256 assetId = daiAssetId; // on all spokes
    uint256 spokeCount = hub1.getSpokeCount(assetId);
    updateLiquidityFee(hub1, assetId, MAX_LIQUIDITY_FEE);
    // build spoke list excluding treasury spoke
    ISpoke[] memory spokes = new ISpoke[](spokeCount - 1);
    uint256 spokeIndex;
    for (uint256 i; i < spokeCount; ++i) {
      if (hub1.getSpokeAddress(assetId, i) != address(treasurySpoke)) {
        spokes[spokeIndex++] = ISpoke(hub1.getSpokeAddress(assetId, i));
      }
    }

    uint256 count = vm.randomUint(10, 1000);
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i);
      uint256 borrowAmount = vm.randomUint(1, MAX_SUPPLY_AMOUNT / count);
      ISpoke spoke = spokes[i % spokes.length]; // to deterministically pick random spoke
      uint256 reserveId = _reserveId(spoke, assetId);
      _backedBorrow(spoke, user, reserveId, reserveId, borrowAmount);
    }
    uint256 totalOwedBefore = hub1.getAssetTotalOwed(assetId);

    skip(vm.randomUint(1, MAX_SKIP_TIME));

    uint256 feesAccrued;
    for (uint256 i; i < count; ++i) {
      address user = makeUser(i); // deterministic operation
      ISpoke spoke = spokes[i % spokes.length]; // deterministic operation
      uint256 reserveId = _reserveId(spoke, assetId);
      uint256 totalOwedAfter = hub1.getAssetTotalOwed(assetId);
      Utils.repay(spoke, reserveId, user, 1, user); // accrue interest & realize premium
      assertApproxEqAbs(totalOwedAfter, hub1.getAssetTotalOwed(assetId), 1);

      feesAccrued += totalOwedAfter - totalOwedBefore;
      totalOwedBefore = hub1.getAssetTotalOwed(assetId);

      uint256 actualFeesAccrued = _getExpectedFeeReceiverAddedAssets(hub1, assetId);
      assertApproxEqRel(actualFeesAccrued, feesAccrued, 0.0000001e18); // 0.00001%
      assertLe(actualFeesAccrued, feesAccrued, 'actual fees <= expected fees');

      skip(vm.randomUint(0, MAX_SKIP_TIME / count));
    }
  }

  /// @dev Diagnostic test: traces through the fee calculation step by step.
  function test_accrueLiquidityFee_feeRoundsToZero_8dec_1second() public {
    uint256 reserveId = _wbtcReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    // 0.01% liquidity fee (1 BPS)
    uint256 liquidityFee = 1;
    updateLiquidityFee(hub1, assetId, liquidityFee);

    // 0 premium
    _updateCollateralRisk(spoke1, reserveId, 0);

    // 6307.2% borrow rate (fits in uint96)
    _mockInterestRateBps(6307_00); // Even 6307 works

    // 50 WBTC = 5_000_000_000 units (8 decimals)
    _backedBorrow(spoke1, alice, reserveId, reserveId, 50e8);

    // Log state before skip
    _logAssetState(assetId);

    // Advance 1 second & trace fee calculation
    skip(1);
    _logFeeCalculationTrace(assetId, liquidityFee);

    // Trigger actual accrual and log result
    Utils.mintFeeShares(hub1, assetId, ADMIN);
    _logActualResult(assetId);
  }

  function _logAssetState(uint256 assetId) internal view {
    IHub.Asset memory a = hub1.getAsset(assetId);
    console.log('=== ASSET STATE ===');
    console.log('decimals:', a.decimals);
    console.log('liquidityFee (BPS):', a.liquidityFee);
    console.log('drawnRate (RAY):', a.drawnRate);
    console.log('drawnIndex (RAY):', a.drawnIndex);
    console.log('drawnShares:', a.drawnShares);
    console.log('lastUpdateTimestamp:', a.lastUpdateTimestamp);

    (uint256 drawnDebt, ) = hub1.getAssetOwed(assetId);
    console.log('drawnDebt (assets):', drawnDebt);
  }

  function _logFeeCalculationTrace(uint256 assetId, uint256 liquidityFee) internal view {
    IHub.Asset memory a = hub1.getAsset(assetId);
    console.log('');
    console.log('=== FEE CALCULATION TRACE (after skip 1s) ===');

    // Step 1: Linear interest
    uint256 linearInterest = MathUtils.calculateLinearInterest(
      uint96(a.drawnRate),
      uint40(a.lastUpdateTimestamp)
    );
    console.log('1. linearInterest (RAY):', linearInterest);
    console.log('   indexDelta:', linearInterest - WadRayMath.RAY);

    // Step 2: Index
    uint256 prevIdx = a.drawnIndex;
    uint256 newIdx = prevIdx.rayMulUp(linearInterest);
    console.log('2. previousIndex:', prevIdx);
    console.log('   newDrawnIndex:', newIdx);
    console.log('   indexGrowth:', newIdx - prevIdx);

    // Step 3 & 4: Aggregated owed before & after
    _logAggregatedOwed(a, prevIdx, newIdx, liquidityFee);
  }

  function _logAggregatedOwed(
    IHub.Asset memory a,
    uint256 prevIdx,
    uint256 newIdx,
    uint256 liquidityFee
  ) internal pure {
    // Before
    uint256 aggOwedRayBefore = a.drawnShares * prevIdx;
    uint256 aggOwedBefore = aggOwedRayBefore.fromRayUp();
    console.log('3. aggregatedOwedRayBefore:', aggOwedRayBefore);
    console.log('   fromRayUp(before):', aggOwedBefore);

    // After
    uint256 aggOwedRayAfter = a.drawnShares * newIdx;
    uint256 aggOwedAfter = aggOwedRayAfter.fromRayUp();
    console.log('4. aggregatedOwedRayAfter:', aggOwedRayAfter);
    console.log('   fromRayUp(after):', aggOwedAfter);

    // Growth & fee
    uint256 debtGrowth = aggOwedAfter - aggOwedBefore;
    uint256 fee = debtGrowth.percentMulDown(liquidityFee);
    console.log('5. debtGrowth (assets):', debtGrowth);
    console.log('6. percentMulDown(debtGrowth, liquidityFee)');
    console.log('   debtGrowth:', debtGrowth, 'liquidityFee:', liquidityFee);
    console.log('   fee:', fee);
  }

  function _logActualResult(uint256 assetId) internal view {
    IHub.Asset memory a = hub1.getAsset(assetId);
    console.log('');
    console.log('=== ACTUAL ACCRUAL RESULT ===');
    console.log('realizedFees:', a.realizedFees);
    console.log('treasury shares:', hub1.getSpokeAddedShares(assetId, address(treasurySpoke)));
    console.log('newDrawnIndex:', a.drawnIndex);
  }
}
