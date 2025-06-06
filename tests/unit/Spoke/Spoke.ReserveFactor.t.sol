// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeReserveFactorTest is SpokeBase {
  using SharesMath for uint256;
  using WadRayMathExtended for uint256;
  using PercentageMath for uint256;
  using PercentageMathExtended for uint256;
  using WadRayMath for uint256;

  function test_reserveFactor_NoActionTaken() public view {
    assertEq(hub.getSpokeSuppliedShares(daiAssetId, address(treasurySpoke)), 0);
    _assertSingleUserProtocolDebt(
      spoke1,
      _daiReserveId(spoke1),
      bob,
      0,
      0,
      'no debt without action'
    );
  }

  /// Supply an asset only, and check no interest accrued.
  function test_reserveFactor_NoInterest_OnlySupply(uint40 skipTime) public {
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME));
    uint256 amount = 1000e18;
    uint256 daiReserveId = _daiReserveId(spoke1);

    // Bob supplies through spoke 1
    Utils.supply(spoke1, daiReserveId, bob, amount, bob);

    // Skip time
    skip(skipTime);

    _assertSingleUserProtocolDebt(
      spoke1,
      daiReserveId,
      bob,
      0,
      0,
      'after supply, no interest accrued'
    );

    // treasury
    assertEq(hub.getSpokeSuppliedAmount(daiAssetId, address(treasurySpoke)), 0);
  }

  function test_reserveFactor_fuzz_BorrowAmountAndSkipTime(
    uint256 borrowAmount,
    uint40 skipTime
  ) public {
    borrowAmount = bound(borrowAmount, 1, MAX_SUPPLY_AMOUNT / 2);
    skipTime = uint40(bound(skipTime, 0, MAX_SKIP_TIME / 3));
    uint256 supplyAmount = borrowAmount * 2;
    uint40 startTime = uint40(vm.getBlockTimestamp());
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    // Bob supplies and borrows through spoke 1
    Utils.supplyCollateral(spoke1, reserveId, bob, supplyAmount, bob);
    Utils.borrow(spoke1, reserveId, bob, borrowAmount, bob);

    uint256 baseBorrowRate = hub.getBaseInterestRate(assetId);
    uint256 initialBaseIndex = hub.getAsset(assetId).baseDebtIndex;
    uint256 userRp = spoke1.getUserRiskPremium(bob);

    // withdraw any treasury fees
    treasuryWithdraw(assetId, type(uint256).max);

    // Time passes
    skip(skipTime);

    DataTypes.UserPosition memory bobPosition = spoke1.getUserPosition(reserveId, bob);
    {
      uint256 baseDebt = _calculateExpectedBaseDebt(borrowAmount, baseBorrowRate, startTime);
      uint256 expectedPremiumDrawnShares = bobPosition.baseDrawnShares.percentMul(userRp);
      uint256 expectedPremiumDebt = hub.convertToDrawnAssets(assetId, expectedPremiumDrawnShares) -
        bobPosition.premiumOffset +
        bobPosition.realizedPremium;

      _assertSingleUserProtocolDebt(
        spoke1,
        reserveId,
        bob,
        baseDebt,
        expectedPremiumDebt,
        'after accrual'
      );
    }

    // Alice supplies 1 share to trigger interest accrual
    Utils.supplyCollateral(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    // treasury
    uint256 expectedFeesShares = hub.convertToSuppliedShares(
      assetId,
      calculateExpectedFeesAmount({
        initialDrawnShares: bobPosition.baseDrawnShares,
        initialPremiumShares: bobPosition.premiumDrawnShares,
        reserveFactor: _getReserveFactor(assetId),
        indexDelta: hub.getAsset(assetId).baseDebtIndex - initialBaseIndex
      })
    );

    assertApproxEqAbs(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      expectedFeesShares,
      1,
      'treasury shares'
    );

    // now only base debt grows
    updateLiquidityPremium(spoke1, reserveId, 0);
    spoke1.updateUserRiskPremium(bob);

    // refresh
    initialBaseIndex = hub.getAsset(assetId).baseDebtIndex;

    // withdraw any treasury fees
    treasuryWithdraw(assetId, type(uint256).max);

    // todo: updateLiquidityPremium, updateReserveFactor or updateInterestRateStrategy needs reserve update?

    // Time passes
    skip(skipTime);

    // Alice supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    // treasury
    expectedFeesShares = hub.convertToSuppliedShares(
      assetId,
      calculateExpectedFeesAmount({
        initialDrawnShares: bobPosition.baseDrawnShares,
        initialPremiumShares: 0,
        reserveFactor: _getReserveFactor(assetId),
        indexDelta: hub.getAsset(assetId).baseDebtIndex - initialBaseIndex
      })
    );

    assertApproxEqAbs(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      expectedFeesShares,
      1,
      'treasury shares'
    );

    // now no reserve factor, so no fees
    updateReserveFactor(hub, assetId, 0);

    // withdraw any treasury fees
    treasuryWithdraw(assetId, type(uint256).max);

    // Time passes
    skip(skipTime);

    // Alice supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    // treasury
    expectedFeesShares = 0;

    assertApproxEqAbs(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      expectedFeesShares,
      1,
      'treasury shares'
    );
  }

  function test_reserveFactor_accrual() public {
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 assetId = spoke1.getReserve(reserveId).assetId;

    // 10% premium
    updateLiquidityPremium(spoke1, reserveId, 10_00);
    // 5% reserve factor
    updateReserveFactor(hub, assetId, 5_00);

    uint256 borrowAmount = 1000e18;
    uint256 supplyAmount = _calcMinimumCollAmount(spoke1, reserveId, reserveId, borrowAmount);
    uint256 rate = 50_00; // 50.00% base borrow rate
    uint256 expectedBaseDebt = borrowAmount + 500e18; // 50% of 1000 (base debt accrual)
    uint256 expectedPremiumDebt = 50e18; // 10% of 500 (premium on base debt)
    uint256 expectedTreasuryFees = 27.5e18; // 5% of 550 (reserve factor on base debt)

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate.bpsToRay())
    );

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    skip(365 days);

    assertDebtEq(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base and premium debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees'
    );

    // 0% premium
    updateLiquidityPremium(spoke1, reserveId, 0);
    spoke1.updateUserRiskPremium(alice);

    // Bob supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    spoke1.getUserDebt(reserveId, alice);

    expectedBaseDebt += 750e18; // 50% of 1500 (base debt accrual)
    expectedPremiumDebt += 0;
    expectedTreasuryFees += 37.5e18; // 5% of 750 (reserve factor on base debt)

    skip(365 days);

    assertDebtEq(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees'
    );

    // 0.00% reserve factor
    updateReserveFactor(hub, assetId, 0);

    // Bob supplies 1 share to trigger interest accrual
    Utils.supply(spoke1, reserveId, alice, minimumAssetsPerSuppliedShare(assetId), alice);

    expectedBaseDebt += 1125e18; // 50% of 2250 (base debt accrual)
    expectedPremiumDebt += 0;
    expectedTreasuryFees += 0;

    skip(365 days);

    assertDebtEq(
      spoke1,
      reserveId,
      expectedBaseDebt,
      expectedPremiumDebt,
      'after base debt accrual'
    );
    assertEq(
      hub.getSpokeSuppliedShares(assetId, address(treasurySpoke)),
      hub.convertToSuppliedShares(assetId, expectedTreasuryFees),
      'treasury fees'
    );
  }
}
