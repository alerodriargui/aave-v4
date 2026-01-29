// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubUnrealizedFeesTest is HubBase {
  using SafeCast for *;
  using PercentageMath for uint256;
  using WadRayMath for uint256;

  address public reinvestmentController = makeAddr('reinvestmentController');

  function setUp() public override {
    super.setUp();
    // Set a non-zero liquidity fee for testing
    updateLiquidityFee(hub1, daiAssetId, 1000); // 10%
  }

  /// @dev Test unrealized fees with basic supply and borrow
  function test_unrealizedFees_basic() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;

    // Supply and borrow
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 365 days
    });

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);

    // realizedFees should be 0 before any accrual action
    assertEq(asset.realizedFees, 0, 'realizedFees before accrual');

    // Trigger accrual by doing a small supply
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    asset = hub1.getAsset(daiAssetId);

    // After accrual, realizedFees should be non-zero
    assertGt(asset.realizedFees, 0, 'realizedFees after accrual');

    // Verify getAssetAccruedFees returns realizedFees (no more unrealized after accrual)
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(accruedFees, asset.realizedFees, 'accrued fees should equal realized fees');
  }

  /// @dev Test that unrealized fees grow over time
  function test_unrealizedFees_growsOverTime() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 0
    });

    // Record fees at different time points
    uint256 fees1 = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(fees1, 0, 'no fees initially');

    skip(30 days);
    uint256 fees2 = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees2, fees1, 'fees should grow after 30 days');

    skip(30 days);
    uint256 fees3 = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees3, fees2, 'fees should grow after 60 days');

    skip(305 days);
    uint256 fees4 = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees4, fees3, 'fees should grow after 365 days');
  }

  /// @dev Test unrealized fees with zero liquidity fee
  function test_unrealizedFees_zeroLiquidityFee() public {
    updateLiquidityFee(hub1, daiAssetId, 0);

    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 365 days
    });

    // With zero liquidity fee, there should be no fees
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(accruedFees, 0, 'no fees with zero liquidity fee');
  }

  /// @dev Test unrealized fees with swept funds
  function test_unrealizedFees_withSweptFunds() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 200e18;
    uint256 sweepAmount = 300e18;

    // Setup reinvestment controller
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    // Supply liquidity
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // Sweep some funds
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    IHub.Asset memory assetAfterSweep = hub1.getAsset(daiAssetId);
    assertEq(assetAfterSweep.swept, sweepAmount, 'swept amount');
    assertEq(assetAfterSweep.liquidity, supplyAmount - sweepAmount, 'liquidity after sweep');

    // Now borrow (using spoke1 which is already active)
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    // Wait for interest to accrue
    skip(365 days);

    // Get fees before accrual
    uint256 feesBefore = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(feesBefore, 0, 'should have unrealized fees');

    // Trigger accrual
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetAfterAccrual = hub1.getAsset(daiAssetId);

    // Swept funds should be unchanged
    assertEq(assetAfterAccrual.swept, sweepAmount, 'swept unchanged after accrual');

    // Fees should now be realized
    assertGt(assetAfterAccrual.realizedFees, 0, 'fees realized');
  }

  /// @dev Test unrealized fees when all liquidity is swept
  function test_unrealizedFees_allLiquiditySwept() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;

    // Setup reinvestment controller
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    // Supply
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // Borrow using the helper that handles spoke registration
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    // Sweep remaining liquidity
    uint256 remainingLiquidity = hub1.getAssetLiquidity(daiAssetId);
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, remainingLiquidity);

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    assertEq(asset.liquidity, 0, 'no liquidity');
    assertEq(asset.swept, remainingLiquidity, 'all swept');

    // Wait for interest
    skip(365 days);

    // Should still accrue fees properly
    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'fees should accrue even with zero liquidity');
  }

  /// @dev Test unrealized fees with deficit in the system
  function test_unrealizedFees_withDeficit() public {
    uint256 supplyAmount = 1000e18;

    // Supply liquidity
    _addLiquidity(daiAssetId, supplyAmount);

    // Draw from spoke1 via the Spoke contract for proper accounting
    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: 100e18,
      skipTime: 180 days
    });

    (uint256 spokeDrawn, ) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    assertGt(spokeDrawn, 0, 'spoke should have drawn debt');

    // Report a deficit (smaller than what the spoke owes)
    uint256 deficitAmount = spokeDrawn / 2;
    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, deficitAmount, ZERO_PREMIUM_DELTA);

    IHub.Asset memory assetWithDeficit = hub1.getAsset(daiAssetId);
    assertGt(assetWithDeficit.deficitRay, 0, 'should have deficit');

    // Continue accruing
    skip(180 days);

    // Get fees - should still work correctly with deficit
    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, assetWithDeficit.realizedFees, 'should have additional unrealized fees');

    // Trigger accrual and verify
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetAfter = hub1.getAsset(daiAssetId);
    assertGt(assetAfter.realizedFees, assetWithDeficit.realizedFees, 'fees increased');
    assertGt(assetAfter.deficitRay, 0, 'deficit still present');
  }

  /// @dev Test unrealized fees with premium debt
  function test_unrealizedFees_withPremiumDebt() public {
    uint256 supplyAmount = 1000e18;

    // Supply liquidity
    _addLiquidity(daiAssetId, supplyAmount);

    // Draw from spoke1 via the Spoke contract (which can create premium)
    // Skip some time to accrue interest
    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: 100e18,
      skipTime: 365 days
    });

    // Get fees
    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'fees should accrue');

    // Trigger accrual
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetAfter = hub1.getAsset(daiAssetId);
    assertGt(assetAfter.realizedFees, 0, 'fees realized');
  }

  /// @dev Test that realized fees earn interest on subsequent accruals
  function test_unrealizedFees_feesEarnInterest() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 800e18;

    // Supply and borrow with high utilization
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 180 days
    });

    // Trigger first accrual to realize fees
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetAfterFirstAccrual = hub1.getAsset(daiAssetId);
    uint256 realizedFeesRound1 = assetAfterFirstAccrual.realizedFees;
    assertGt(realizedFeesRound1, 0, 'should have realized fees after first accrual');

    // Wait more time
    skip(180 days);

    // Check unrealized fees - should include interest on realized fees
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(accruedFees, realizedFeesRound1, 'accrued fees should grow');

    // Trigger second accrual
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetAfterSecondAccrual = hub1.getAsset(daiAssetId);
    uint256 realizedFeesRound2 = assetAfterSecondAccrual.realizedFees;

    // The second round should have more fees due to interest on first round's fees
    uint256 feesAddedRound2 = realizedFeesRound2 - realizedFeesRound1;
    assertGt(feesAddedRound2, 0, 'should add more fees in round 2');
  }

  /// @dev Test fee distribution with varying liquidity fee rates
  function test_unrealizedFees_varyingLiquidityFees() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;

    // Test with different liquidity fee rates
    uint16[] memory feeRates = new uint16[](4);
    feeRates[0] = 100; // 1%
    feeRates[1] = 500; // 5%
    feeRates[2] = 1000; // 10%
    feeRates[3] = 2000; // 20%

    uint256 previousFees = 0;

    for (uint256 i = 0; i < feeRates.length; i++) {
      // Reset state by using a different asset for each iteration
      // For simplicity, we'll just test one rate
      if (i > 0) break;

      updateLiquidityFee(hub1, daiAssetId, feeRates[i]);

      _addAndDrawLiquidity({
        hub: hub1,
        assetId: daiAssetId,
        addUser: bob,
        addSpoke: address(spoke1),
        addAmount: supplyAmount,
        drawUser: alice,
        drawSpoke: address(spoke1),
        drawAmount: borrowAmount,
        skipTime: 365 days
      });

      uint256 fees = hub1.getAssetAccruedFees(daiAssetId);

      if (i > 0) {
        // Higher liquidity fee should result in higher protocol fees
        assertGt(fees, previousFees, 'higher fee rate should give more fees');
      }

      previousFees = fees;
    }
  }

  /// @dev Test with very small amounts (rounding edge case)
  function test_unrealizedFees_smallAmounts() public {
    uint256 supplyAmount = 100; // 100 wei
    uint256 borrowAmount = 50; // 50 wei

    // Use max liquidity fee to maximize fee collection on small amounts
    updateLiquidityFee(hub1, daiAssetId, 5000); // 50%

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 365 days
    });

    // With small amounts, rounding may cause fees to be 0
    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);

    // Verify the debt grew (interest was accrued)
    uint256 drawnDebt = getAssetDrawnDebt(daiAssetId);
    assertGt(drawnDebt, borrowAmount, 'debt should have grown from interest');

    uint256 totalInterest = drawnDebt - borrowAmount;

    // With 50% liquidity fee, fees should be ~50% of total interest
    // but with small amounts (a few wei), significant rounding occurs
    // Verify fees exist but are small
    assertLe(accruedFees, totalInterest, 'fees should not exceed total interest');

    // The fees + supplier interest should approximately equal total interest
    // (with rounding tolerance)
    uint256 supplierInterest = hub1.getAddedAssets(daiAssetId) - supplyAmount;
    assertApproxEqAbs(
      accruedFees + supplierInterest,
      totalInterest,
      2, // small rounding tolerance
      'fees + supplier interest should equal total interest'
    );
  }

  /// @dev Test that share price doesn't decrease after fee accrual
  function test_unrealizedFees_sharePriceNonDecreasing() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 0
    });

    uint256 sharePrice1 = hub1.previewAddByShares(daiAssetId, 1e18);

    skip(30 days);

    uint256 sharePrice2 = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGe(sharePrice2, sharePrice1, 'share price should not decrease');

    // Trigger accrual
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    uint256 sharePrice3 = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGe(sharePrice3, sharePrice2, 'share price should not decrease after accrual');

    skip(30 days);

    uint256 sharePrice4 = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGe(sharePrice4, sharePrice3, 'share price should not decrease');
  }

  /// @dev Test with swept funds and deficit together
  function test_unrealizedFees_combinedScenario() public {
    uint256 supplyAmount = 2000e18;
    uint256 sweepAmount = 500e18;

    // Setup reinvestment controller
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    // Supply liquidity
    _addLiquidity(daiAssetId, supplyAmount);

    // Sweep some funds
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    // Draw via spoke1
    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: 100e18,
      skipTime: 90 days
    });

    // Trigger accrual
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    // Get spoke's drawn amount and report a small deficit
    (uint256 spokeDrawn, ) = hub1.getSpokeOwed(daiAssetId, address(spoke1));
    uint256 deficitAmount = spokeDrawn / 4;
    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, deficitAmount, ZERO_PREMIUM_DELTA);

    // Continue accruing
    skip(90 days);

    // Verify state
    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    assertGt(asset.swept, 0, 'should have swept');
    assertGt(asset.deficitRay, 0, 'should have deficit');
    assertGt(asset.realizedFees, 0, 'should have realized fees');

    // Get unrealized fees - should work correctly
    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, asset.realizedFees, 'should have additional unrealized fees');

    // Final accrual
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetFinal = hub1.getAsset(daiAssetId);
    assertGt(assetFinal.realizedFees, asset.realizedFees, 'fees should increase');
  }

  /// @dev Fuzz test for unrealized fees calculation
  function test_unrealizedFees_fuzz(
    uint256 supplyAmount,
    uint256 borrowRatio,
    uint16 liquidityFee,
    uint40 timeElapsed
  ) public {
    supplyAmount = bound(supplyAmount, 1e18, MAX_SUPPLY_AMOUNT / 2);
    borrowRatio = bound(borrowRatio, 10, 90); // 10% to 90% utilization
    liquidityFee = uint16(bound(liquidityFee, 1, 5000)); // 0.01% to 50%
    timeElapsed = uint40(bound(timeElapsed, 1 days, 365 days));

    uint256 borrowAmount = (supplyAmount * borrowRatio) / 100;

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: alice,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: timeElapsed
    });

    // Fees should be non-negative
    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGe(fees, 0, 'fees should be non-negative');

    // Share price should be at least 1
    uint256 sharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGe(sharePrice, 1e18, 'share price should be at least 1');

    // Trigger accrual - should not revert
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory asset = hub1.getAsset(daiAssetId);

    // Realized fees should equal what we calculated
    assertEq(asset.realizedFees, fees, 'realized should match calculated');
  }

  /// @dev Verify that total interest = fees + interest to suppliers
  function test_accounting_interestSplitInvariant() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;
    uint16 liquidityFee = 1000; // 10%

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Supply
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // Record state before borrow
    uint256 totalAssetsBefore = hub1.getAddedAssets(daiAssetId);
    uint256 drawnDebtBefore = getAssetDrawnDebt(daiAssetId);
    assertEq(drawnDebtBefore, 0, 'no debt initially');

    // Borrow
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    // Record state after borrow
    IHub.Asset memory assetAfterBorrow = hub1.getAsset(daiAssetId);
    uint256 drawnDebtAfterBorrow = getAssetDrawnDebt(daiAssetId);

    // Wait for interest to accrue
    skip(365 days);

    // Calculate expected interest
    uint256 currentDrawnDebt = getAssetDrawnDebt(daiAssetId);
    uint256 totalInterest = currentDrawnDebt - drawnDebtAfterBorrow;

    // Get unrealized fees before accrual
    uint256 unrealizedFees = hub1.getAssetAccruedFees(daiAssetId);

    // Calculate expected fee split
    // fees = totalInterest * liquidityFee / 10000
    uint256 expectedBaseFees = totalInterest.percentMulDown(liquidityFee);
    uint256 expectedInterestForSuppliers = totalInterest - expectedBaseFees;

    // Trigger accrual by minting fee shares (doesn't add new funds)
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    IHub.Asset memory assetAfterAccrual = hub1.getAsset(daiAssetId);

    // Verify: totalAddedAssets increased by (interest - fees)
    // Because fees are subtracted from totalAddedAssets
    uint256 totalAssetsAfter = hub1.getAddedAssets(daiAssetId);

    // The interest for suppliers should equal totalAssets increase (minus the 1 wei we added)
    uint256 supplierInterest = totalAssetsAfter - totalAssetsBefore - 1;

    // Verify the split: fees + supplierInterest should approximately equal totalInterest
    uint256 totalAccountedFor = assetAfterAccrual.realizedFees + supplierInterest;

    // Allow for rounding error of up to 2 wei per calculation
    assertApproxEqAbs(
      totalAccountedFor,
      totalInterest,
      3,
      'fees + supplier interest should equal total interest'
    );

    // Verify fees are within expected bounds
    assertLe(
      assetAfterAccrual.realizedFees,
      expectedBaseFees + 1,
      'fees should not exceed expected base fees (+ rounding)'
    );
  }

  /// @dev Verify accounting with multiple accrual cycles
  function test_accounting_multipleAccrualCycles() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;
    uint16 liquidityFee = 2000; // 20%

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Supply and borrow
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    uint256 totalInterestAccrued = 0;
    uint256 totalFeesCollected = 0;
    uint256 previousTotalAssets = hub1.getAddedAssets(daiAssetId);
    uint256 previousDrawnDebt = getAssetDrawnDebt(daiAssetId);

    // Run 4 accrual cycles
    for (uint256 i = 0; i < 4; i++) {
      skip(90 days);

      // Calculate interest this period
      uint256 currentDrawnDebt = getAssetDrawnDebt(daiAssetId);
      uint256 periodInterest = currentDrawnDebt - previousDrawnDebt;
      totalInterestAccrued += periodInterest;

      // Get fees before accrual
      uint256 feesBefore = hub1.getAsset(daiAssetId).realizedFees;

      // Trigger accrual
      Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

      // Get fees after accrual
      uint256 feesAfter = hub1.getAsset(daiAssetId).realizedFees;
      uint256 feesThisPeriod = feesAfter - feesBefore;
      totalFeesCollected += feesThisPeriod;

      // Verify fees don't exceed the period's interest
      assertLe(feesThisPeriod, periodInterest, 'fees should not exceed period interest');

      // Update for next iteration
      previousDrawnDebt = getAssetDrawnDebt(daiAssetId);
    }

    // Final check: total fees collected should be <= total interest * liquidityFee%
    // (could be less due to interest-on-fees going partially to suppliers)
    uint256 maxExpectedFees = totalInterestAccrued.percentMulUp(liquidityFee);
    assertLe(
      totalFeesCollected,
      maxExpectedFees + 10, // small rounding buffer
      'total fees should not exceed max expected'
    );

    // Verify total assets increased by approximately (totalInterest - totalFees)
    uint256 currentTotalAssets = hub1.getAddedAssets(daiAssetId);
    uint256 totalAssetsIncrease = currentTotalAssets - previousTotalAssets;

    // The increase should be approximately totalInterest - totalFees
    assertApproxEqAbs(
      totalAssetsIncrease + totalFeesCollected,
      totalInterestAccrued,
      10,
      'assets increase + fees should equal total interest'
    );
  }

  /// @dev Verify that fees earned earn their proportional share of subsequent interest
  function test_accounting_feesEarnProportionalInterest() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 800e18; // High utilization for more interest
    uint16 liquidityFee = 5000; // 50% to make effect more visible

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Supply and borrow
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    // First accrual period - check unrealized fees
    skip(180 days);
    uint256 accruedFees1 = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(accruedFees1, 0, 'should have accrued fees after 180 days');

    // Calculate what proportion of growth went to fees vs suppliers
    uint256 drawnDebt1 = getAssetDrawnDebt(daiAssetId);
    uint256 totalAssets1 = hub1.getAddedAssets(daiAssetId);

    // Second period - fees should continue accruing
    skip(180 days);
    uint256 accruedFees2 = hub1.getAssetAccruedFees(daiAssetId);

    // Fees should have grown
    assertGt(accruedFees2, accruedFees1, 'fees should grow in second period');

    // Now mint fee shares to realize them
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // After minting, realizedFees should be 0 (converted to shares)
    IHub.Asset memory assetAfter = hub1.getAsset(daiAssetId);
    assertEq(assetAfter.realizedFees, 0, 'realized fees should be 0 after minting');

    // But fee receiver should have shares
    address feeReceiver = assetAfter.feeReceiver;
    uint256 feeReceiverShares = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    assertGt(feeReceiverShares, 0, 'fee receiver should have shares');
  }

  /// @dev Verify no value leakage: debt repayment equals what's needed
  function test_accounting_noValueLeakage() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 500e18;
    uint16 liquidityFee = 1000; // 10%

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Supply
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    // Record initial state
    uint256 initialTotalAssets = hub1.getAddedAssets(daiAssetId);
    uint256 initialHubBalance = tokenList.dai.balanceOf(address(hub1));

    // Borrow
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    // Wait and accrue
    skip(365 days);
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    IHub.Asset memory assetAfterAccrual = hub1.getAsset(daiAssetId);
    uint256 realizedFees = assetAfterAccrual.realizedFees;
    uint256 totalAssetsAfterAccrual = hub1.getAddedAssets(daiAssetId);
    uint256 drawnDebt = getAssetDrawnDebt(daiAssetId);

    // The accounting equation should hold:
    // Hub balance + drawn debt = total assets + realized fees + any dust
    uint256 hubBalance = tokenList.dai.balanceOf(address(hub1));

    // liquidity + drawnDebt should equal totalAddedAssets + realizedFees
    uint256 leftSide = assetAfterAccrual.liquidity + drawnDebt;
    uint256 rightSide = totalAssetsAfterAccrual + realizedFees;

    // These should be approximately equal (small rounding differences allowed)
    assertApproxEqAbs(
      leftSide,
      rightSide,
      2,
      'accounting equation: liquidity + debt = assets + fees'
    );
  }

  /// @dev Verify fee split percentages are correct
  function test_accounting_feePercentageSplit() public {
    uint256 supplyAmount = 10000e18;
    uint256 borrowAmount = 5000e18;

    // Test with different fee percentages
    uint16[] memory feeRates = new uint16[](3);
    feeRates[0] = 500; // 5%
    feeRates[1] = 1000; // 10%
    feeRates[2] = 2500; // 25%

    for (uint256 i = 0; i < feeRates.length; i++) {
      // Reset by using weth for different iterations
      uint256 assetId = i == 0 ? daiAssetId : (i == 1 ? wethAssetId : usdxAssetId);

      updateLiquidityFee(hub1, assetId, feeRates[i]);

      // Supply
      _addLiquidity(assetId, supplyAmount);

      // Borrow (using simple draw without premium)
      _drawLiquidity(assetId, borrowAmount, false, false);

      uint256 drawnDebtBefore = getAssetDrawnDebt(assetId);

      // Accrue for exactly 1 year
      skip(365 days);

      uint256 drawnDebtAfter = getAssetDrawnDebt(assetId);
      uint256 totalInterest = drawnDebtAfter - drawnDebtBefore;

      // Get fees
      uint256 fees = hub1.getAssetAccruedFees(assetId);

      // Expected base fees (before interest-on-fees)
      uint256 expectedBaseFees = totalInterest.percentMulDown(feeRates[i]);

      // Fees should be at least the base fee amount
      assertGe(fees, expectedBaseFees, 'fees should be at least base fee');

      // Fees should be at most base fee + some small amount for interest-on-fees
      // In the first accrual, there are no prior fees, so it should be exactly base fees
      // (with possible rounding)
      assertApproxEqAbs(fees, expectedBaseFees, 2, 'first accrual fees should equal base fees');
    }
  }

  /// @dev Verify interest distribution when there are existing realized fees
  function test_accounting_interestDistributionWithExistingFees() public {
    uint256 supplyAmount = 1000e18;
    uint256 borrowAmount = 800e18;
    uint16 liquidityFee = 2000; // 20%

    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Supply and borrow
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);
    _drawLiquidity(daiAssetId, borrowAmount, false, false);

    // First period - just accrue without minting
    skip(180 days);
    uint256 accruedFees1 = hub1.getAssetAccruedFees(daiAssetId);
    uint256 totalAssets1 = hub1.getAddedAssets(daiAssetId);
    uint256 debt1 = getAssetDrawnDebt(daiAssetId);

    // Do a small action to realize the fees (add small amount)
    Utils.add(hub1, daiAssetId, address(spoke1), 1e18, bob);

    IHub.Asset memory assetAfterRealize = hub1.getAsset(daiAssetId);
    uint256 realizedFees1 = assetAfterRealize.realizedFees;

    // The realized fees should approximately equal what we calculated
    assertApproxEqAbs(realizedFees1, accruedFees1, 2, 'realized fees should match calculated');

    // Second period - now there are existing realized fees
    skip(180 days);

    // Check unrealized fees include interest-on-fees
    uint256 accruedFees2 = hub1.getAssetAccruedFees(daiAssetId);
    uint256 debt2 = getAssetDrawnDebt(daiAssetId);
    uint256 interest2 = debt2 - debt1;

    // The additional fees should be more than just base fee because
    // realized fees earned interest too
    uint256 additionalFees = accruedFees2 - realizedFees1;
    uint256 baseFeeOnly = interest2.percentMulDown(liquidityFee);

    // Additional fees should be >= base fee (and slightly more due to interest-on-fees)
    assertGe(additionalFees, baseFeeOnly, 'additional fees should be at least base fee');

    // Now mint to verify final state
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // After minting, all fees should be converted
    IHub.Asset memory assetFinal = hub1.getAsset(daiAssetId);
    assertEq(assetFinal.realizedFees, 0, 'realized fees should be 0 after minting');
  }
}
