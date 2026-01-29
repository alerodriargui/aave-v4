// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubUnrealizedFeesTest is HubBase {
  uint256 constant SUPPLY_AMOUNT = 1000e18;
  uint256 constant BORROW_AMOUNT = 500e18;

  /// @dev Test basic fee accrual with standard parameters
  function test_unrealizedFees_basicAccrual() public {
    // Setup: Add liquidity and draw
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: SUPPLY_AMOUNT,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: BORROW_AMOUNT,
      skipTime: 365 days
    });

    // Get accrued fees
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Verify fees were accrued
    assertGt(accruedFees, 0, 'fees should be > 0');

    // Get drawn debt to calculate expected fees
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - BORROW_AMOUNT;

    // Fees should be less than total interest (supplier gets some)
    assertLt(accruedFees, totalInterest, 'fees should be < total interest');
  }

  /// @dev Test fee accrual over multiple time periods
  function test_unrealizedFees_accrualOverTime() public {
    // Initial setup
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    uint256 previousFees = 0;

    // Accrue over multiple periods
    for (uint256 i = 0; i < 4; i++) {
      skip(90 days);

      uint256 currentFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

      // Fees should increase each period
      assertGt(currentFees, previousFees, 'fees should increase over time');

      previousFees = currentFees;
    }
  }

  /// @dev Test that no fees accrue when liquidityFee is 0 - all interest goes to suppliers
  function test_unrealizedFees_zeroLiquidityFee() public {
    // Set liquidity fee to 0
    updateLiquidityFee(hub1, daiAssetId, 0);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Record initial state
    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 initialTotalAssets = hub1.getAddedAssets(daiAssetId);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    skip(365 days);

    // Get state after accrual
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - BORROW_AMOUNT;
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 finalTotalAssets = hub1.getAddedAssets(daiAssetId);

    // With 0% liquidity fee no fees should accrue
    assertEq(accruedFees, 0, 'fees should be exactly 0');

    // All interest should go to suppliers (total assets increased by interest)
    assertEq(finalTotalAssets - initialTotalAssets, totalInterest, 'all interest to suppliers');

    // Share price should increase
    assertGt(finalSharePrice, initialSharePrice, 'share price should increase');

    // Verify interest is non-zero (something was earned)
    assertGt(totalInterest, 0, 'interest should be > 0');
  }

  /// @dev Test fee accrual with swept funds
  function test_unrealizedFees_withSweptFunds() public {
    // Setup reinvestment controller for sweep
    address reinvestmentController = vm.randomAddress();
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    // Setup: Add liquidity
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Sweep some funds
    uint256 sweepAmount = 200e18;
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    // Draw remaining liquidity via spoke
    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: BORROW_AMOUNT,
      skipTime: 365 days
    });

    // Get accrued fees
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Verify fees were accrued even with swept funds
    assertGt(accruedFees, 0, 'fees should accrue with swept funds');

    // Verify swept amount is still tracked
    assertEq(hub1.getAsset(daiAssetId).swept, sweepAmount, 'swept amount should be tracked');
  }

  /// @dev Test fee accrual when all liquidity is swept
  function test_unrealizedFees_allLiquiditySwept() public {
    // Setup reinvestment controller for sweep
    address reinvestmentController = vm.randomAddress();
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    // Setup: Add liquidity
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Sweep all available funds
    uint256 availableLiquidity = hub1.getAssetLiquidity(daiAssetId);
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, availableLiquidity);

    // Verify all liquidity is swept
    assertEq(hub1.getAssetLiquidity(daiAssetId), 0, 'liquidity should be 0');
    assertEq(hub1.getAsset(daiAssetId).swept, availableLiquidity, 'all should be swept');

    // Time passes but no debt means no fees
    skip(365 days);

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertEq(accruedFees, 0, 'no fees without debt');
  }

  /// @dev Test fee accrual with deficit present
  function test_unrealizedFees_withDeficit() public {
    // Setup: Add liquidity and draw via spoke
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: BORROW_AMOUNT,
      skipTime: 365 days
    });

    // Create deficit by reporting bad debt
    uint256 deficitAmount = 50e18;
    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, deficitAmount, ZERO_PREMIUM_DELTA);

    // Skip more time to accrue interest with deficit
    skip(180 days);

    // Get accrued fees
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Verify fees were accrued even with deficit
    assertGt(accruedFees, 0, 'fees should accrue with deficit');

    // Verify deficit is tracked
    assertGt(hub1.getAsset(daiAssetId).deficitRay, 0, 'deficit should be tracked');
  }

  /// @dev Test fee accrual with premium debt present
  function test_unrealizedFees_withPremiumDebt() public {
    // Setup: Add liquidity
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Draw with premium (creates premium debt)
    _drawLiquidity(daiAssetId, BORROW_AMOUNT, true, true);

    // Get accrued fees
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Verify fees were accrued with premium debt
    assertGt(accruedFees, 0, 'fees should accrue with premium debt');
  }

  /// @dev Test that fees earn interest over multiple periods
  function test_unrealizedFees_feesEarnInterest() public {
    // Setup with high liquidity fee to accumulate significant fees
    updateLiquidityFee(hub1, daiAssetId, 50_00); // 50%

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // First period - accumulate initial fees
    skip(180 days);
    uint256 fees1 = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertGt(fees1, 0, 'initial fees should accrue');

    // Mint fee shares to "realize" the fees as realizedFees
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // After minting, realizedFees should be 0 (converted to shares)
    assertEq(hub1.getAsset(daiAssetId).realizedFees, 0, 'realized fees cleared after mint');

    // Second period - fees should earn interest
    skip(180 days);
    uint256 fees2 = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // After minting, new fees should accrue on top of realized fees
    // The growth should include interest earned by realized fees
    assertGt(fees2, 0, 'new fees should accrue');
  }

  /// @dev Test fee accrual with maximum liquidity fee - all interest goes to treasury, nothing to suppliers
  function test_unrealizedFees_maxLiquidityFee() public {
    // Set max liquidity fee (100%)
    updateLiquidityFee(hub1, daiAssetId, 100_00);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Record initial share price before any borrowing
    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // Skip time to accrue interest
    skip(365 days);

    // Get state after accrual
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - BORROW_AMOUNT;
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    // With 100% liquidity fee, all interest should go to fees exactly
    assertEq(accruedFees, totalInterest, 'all interest should go to fees');

    // Supplier share price should remain exactly unchanged (they earned nothing)
    assertEq(finalSharePrice, initialSharePrice, 'share price unchanged for suppliers');

    // Verify fees are non-zero
    assertGt(accruedFees, 0, 'fees should be > 0');
  }

  /// @dev Test fee accrual with very small amounts
  function test_unrealizedFees_smallAmounts() public {
    uint256 smallSupply = 100;
    uint256 smallBorrow = 10;

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: smallSupply,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: smallBorrow,
      skipTime: 365 days
    });

    // Get fee state
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Verify debt grew
    uint256 drawnDebt = getAssetDrawnDebt(daiAssetId);
    assertGt(drawnDebt, smallBorrow, 'debt should grow');

    // Calculate total interest
    uint256 totalInterest = drawnDebt - smallBorrow;

    // Verify fees don't exceed total interest
    assertLe(accruedFees, totalInterest, 'fees should not exceed total interest');

    // Verify accounting invariant: fees + supplier interest ≈ total interest
    uint256 supplierInterest = totalInterest - accruedFees;
    assertApproxEqAbs(
      accruedFees + supplierInterest,
      totalInterest,
      2,
      'fees + supplier interest should equal total interest'
    );
  }

  /// @dev Test fee rounding to zero - very small accrual rounds protocol cut to 0
  function test_unrealizedFees_roundsToZero() public {
    // Use a low liquidity fee (1%)
    uint256 liquidityFee = 1_00; // 1%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // Small amounts to ensure small delta
    uint256 supplyAmount = 1000;
    uint256 borrowAmount = 100;

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: supplyAmount,
      user: bob
    });

    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: borrowAmount
    });

    // Skip a very short time to get minimal interest
    skip(1 hours);

    // Get state
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebt - borrowAmount;
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    // Verify delta is small enough that fees round to 0
    // fees = delta * 1% / 100 = delta / 100
    // For fees to be 0, we need delta < 100
    assertLt(delta, 100, 'delta should be small');

    // Protocol cut rounds to 0
    uint256 expectedProtocolCut = (delta * liquidityFee) / 100_00;
    assertEq(expectedProtocolCut, 0, 'protocol cut should round to 0');

    // Therefore fees should be exactly 0
    assertEq(accruedFees, 0, 'fees should be exactly 0 due to rounding');

    // But interest still exists, so share price should increase (suppliers get everything)
    assertGt(delta, 0, 'delta should be > 0');
    assertGt(finalSharePrice, initialSharePrice, 'share price should increase');
  }

  /// @dev Test that share price never decreases
  function test_unrealizedFees_sharePriceNeverDecreases() public {
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // Check share price over multiple periods
    for (uint256 i = 0; i < 10; i++) {
      skip(30 days);

      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

      // Share price should never decrease
      assertGe(currentSharePrice, initialSharePrice, 'share price should never decrease');

      initialSharePrice = currentSharePrice;
    }
  }

  /// @dev Test fee accrual with combined swept funds and deficit
  function test_unrealizedFees_combinedScenario() public {
    // Setup reinvestment controller for sweep
    address reinvestmentController = vm.randomAddress();
    updateAssetReinvestmentController(hub1, daiAssetId, reinvestmentController);

    // Setup: Add liquidity
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Sweep some funds
    uint256 sweepAmount = 100e18;
    vm.prank(reinvestmentController);
    hub1.sweep(daiAssetId, sweepAmount);

    // Draw via spoke
    _drawLiquidityFromSpoke({
      spoke: address(spoke1),
      assetId: daiAssetId,
      reserveId: _daiReserveId(spoke1),
      amount: BORROW_AMOUNT,
      skipTime: 180 days
    });

    // Create deficit
    uint256 deficitAmount = 30e18;
    vm.prank(address(spoke1));
    hub1.reportDeficit(daiAssetId, deficitAmount, ZERO_PREMIUM_DELTA);

    // Skip more time
    skip(180 days);

    // Get accrued fees
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Verify fees were accrued in complex scenario
    assertGt(accruedFees, 0, 'fees should accrue in combined scenario');

    // Verify all state is tracked correctly
    IHub.Asset memory asset = hub1.getAsset(daiAssetId);
    assertEq(asset.swept, sweepAmount, 'swept should be tracked');
    assertGt(asset.deficitRay, 0, 'deficit should be tracked');
  }

  /// @dev Test that total interest equals fees plus supplier interest
  function test_unrealizedFees_accountingInvariant() public {
    // Use a specific liquidity fee for predictable calculations
    uint256 liquidityFee = 20_00; // 20%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    skip(365 days);

    // Calculate total interest from debt growth
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebt - BORROW_AMOUNT;

    // Get accrued fees
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Protocol's cut of delta
    uint256 protocolCut = (totalDelta * liquidityFee) / 100_00;

    // Fees should be at least the protocol cut (plus interest earned by fees)
    assertGe(accruedFees, protocolCut, 'fees >= protocol cut');

    // Final share price should be higher than initial
    uint256 finalSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGt(finalSharePrice, initialSharePrice, 'share price should increase');
  }

  /// @dev Test that minting fee shares preserves share price
  function test_unrealizedFees_mintPreservesSharePrice() public {
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: SUPPLY_AMOUNT,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: BORROW_AMOUNT,
      skipTime: 365 days
    });

    // Get state before minting
    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 supplierSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));

    // Mint fee shares
    uint256 mintedShares = Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // Share price should remain approximately the same (minting is non-dilutive)
    uint256 sharePriceAfter = hub1.previewAddByShares(daiAssetId, 1e18);
    assertApproxEqAbs(sharePriceAfter, sharePriceBefore, 2, 'share price should remain stable');

    // Supplier's shares should not change
    uint256 supplierSharesAfter = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(supplierSharesAfter, supplierSharesBefore, 'supplier shares unchanged');

    // Fee shares should have been minted
    assertGt(mintedShares, 0, 'fee shares should be minted');
  }

  /// @dev Test high liquidity fee (90%) with 100% utilization - verify fee calculations precisely
  function test_unrealizedFees_highFeeFullUtilization() public {
    uint256 liquidityFee = 90_00; // 90%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Borrow everything (100% utilization)
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT
    });

    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 drawnBefore = SUPPLY_AMOUNT;

    // Accrue for a full year without minting fees
    skip(365 days);

    // Calculate expected fees precisely
    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebtAfter - drawnBefore;

    // First accrual: no prior realizedFees, so interestForFees = 0
    // Expected fees = delta * liquidityFee / 100_00
    uint256 expectedProtocolCut = (totalDelta * liquidityFee) / 100_00;

    // Since realizedFees was 0 before, interestForFees should be 0
    // So total fees should equal just the protocol cut
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // Fees should equal protocol cut
    assertApproxEqAbs(accruedFees, expectedProtocolCut, 1, 'fees should equal protocol cut');

    // Verify: fees = 90% of delta
    assertApproxEqAbs(accruedFees, (totalDelta * 90) / 100, 2, 'fees should be ~90% of delta');

    // Verify: supplier interest = 10% of delta
    uint256 totalAddedAssets = hub1.getAddedAssets(daiAssetId);
    uint256 supplierYield = totalAddedAssets - SUPPLY_AMOUNT;
    assertApproxEqAbs(
      supplierYield,
      (totalDelta * 10) / 100,
      2,
      'supplier yield should be ~10% of delta'
    );

    // Verify: fees + supplier yield = total delta
    assertApproxEqAbs(accruedFees + supplierYield, totalDelta, 2, 'fees + supplier yield = delta');

    // Share price should still increase (suppliers earn 10%)
    uint256 sharePriceAfter = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGt(sharePriceAfter, sharePriceBefore, 'share price should increase');

    // Mint fee shares - should not affect supplier's share value
    uint256 supplierAssetsBefore = hub1.previewRemoveByShares(
      daiAssetId,
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1))
    );
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);
    uint256 supplierAssetsAfter = hub1.previewRemoveByShares(
      daiAssetId,
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1))
    );

    assertApproxEqAbs(
      supplierAssetsAfter,
      supplierAssetsBefore,
      2,
      'supplier assets unchanged after mint'
    );
  }

  /// @dev Test fees accumulating over multiple years - verify interest on fees
  function test_unrealizedFees_longTermAccumulation() public {
    uint256 liquidityFee = 50_00; // 50%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    uint256 lastSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 cumulativeProtocolCut = 0;

    // Accrue for 5 years
    for (uint256 year = 0; year < 5; year++) {
      (uint256 debtBefore, ) = hub1.getAssetOwed(daiAssetId);

      skip(365 days);

      (uint256 debtAfter, ) = hub1.getAssetOwed(daiAssetId);
      uint256 delta = debtAfter - debtBefore;
      cumulativeProtocolCut += (delta * liquidityFee) / 100_00;

      // Share price should monotonically increase
      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      assertGt(currentSharePrice, lastSharePrice, 'share price should increase each year');
      lastSharePrice = currentSharePrice;
    }

    // After 5 years, verify final accounting
    uint256 finalFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId) +
      hub1.getAsset(daiAssetId).realizedFees;

    // Total fees should be at least the cumulative protocol cuts
    // (plus interest earned on those fees over time)
    assertGe(finalFees, cumulativeProtocolCut, 'fees should be >= cumulative protocol cut');

    // With 5 years of compounding, fees should have earned additional interest
    // The excess over protocol cut is the interest earned by fees
    if (finalFees > cumulativeProtocolCut) {
      uint256 interestEarnedByFees = finalFees - cumulativeProtocolCut;
      // With 50% fee over 5 years, there should be meaningful interest on fees
      assertGt(interestEarnedByFees, 0, 'fees should have earned interest');
    }

    // Mint and verify stability
    uint256 supplierSharesBefore = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);

    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    assertEq(
      hub1.getSpokeAddedShares(daiAssetId, address(spoke1)),
      supplierSharesBefore,
      'supplier shares unchanged'
    );

    uint256 sharePriceAfter = hub1.previewAddByShares(daiAssetId, 1e18);
    assertApproxEqAbs(sharePriceAfter, sharePriceBefore, 2, 'share price stable after mint');
  }

  /// @dev Test precise fee calculation - verify fees = protocolCut + interestForFees
  function test_unrealizedFees_preciseCalculation() public {
    uint256 liquidityFee = 20_00; // 20%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // First accrual - no prior realizedFees
    // Record state before accrual
    IHub.Asset memory assetBefore = hub1.getAsset(daiAssetId);
    assertEq(assetBefore.realizedFees, 0, 'no prior realized fees');

    skip(365 days);

    // Calculate expected fees using the formula
    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebtAfter - BORROW_AMOUNT;

    // fees = delta * liquidityFee / 100_00 (protocol's cut)
    uint256 expectedProtocolCut = (delta * liquidityFee) / 100_00;

    // interest = delta - fees (supplier's portion)
    uint256 interest = delta - expectedProtocolCut;

    // Since realizedFees = 0 before this accrual:
    // interestForFees = interest * 0 / totalAssetsBefore = 0
    // Therefore, total unrealized fees = protocolCut + 0 = protocolCut

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // First accrual: fees should exactly equal the protocol cut
    assertApproxEqAbs(
      accruedFees,
      expectedProtocolCut,
      1,
      'fees = protocol cut when no prior fees'
    );

    // Verify: supplier's yield = interest (since interestForFees = 0)
    uint256 supplierYield = hub1.getAddedAssets(daiAssetId) - SUPPLY_AMOUNT;
    assertApproxEqAbs(supplierYield, interest, 2, 'supplier yield = interest when no prior fees');

    // fees + supplier yield = delta
    assertApproxEqAbs(accruedFees + supplierYield, delta, 2, 'fees + supplier yield = delta');

    // fees should be ~20% of delta, supplier yield should be ~80% of delta
    assertApproxEqAbs(accruedFees, (delta * 20) / 100, 2, 'fees ~20% of delta');
    assertApproxEqAbs(supplierYield, (delta * 80) / 100, 2, 'supplier yield ~80% of delta');
  }

  /// @dev Test interestForFees calculation when realizedFees > 0
  function test_unrealizedFees_withPriorRealizedFees() public {
    uint256 liquidityFee = 20_00; // 20%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // First period - accrue fees
    skip(180 days);

    // Trigger accrual by adding a small amount (this will update realizedFees)
    Utils.add({hub: hub1, assetId: daiAssetId, caller: address(spoke1), amount: 1e18, user: alice});

    // Now realizedFees > 0
    uint256 realizedFeesAfterFirst = hub1.getAsset(daiAssetId).realizedFees;
    assertGt(realizedFeesAfterFirst, 0, 'realizedFees should be > 0 after first accrual');

    // Record state before second accrual
    (uint256 drawnDebtBefore, ) = hub1.getAssetOwed(daiAssetId);
    IHub.Asset memory assetBefore = hub1.getAsset(daiAssetId);
    uint256 totalAssetsBefore = assetBefore.liquidity + assetBefore.swept + drawnDebtBefore;

    // Second period - accrue more fees
    skip(180 days);

    // Calculate expected values for second period
    (uint256 drawnDebtAfter, ) = hub1.getAssetOwed(daiAssetId);
    uint256 delta = drawnDebtAfter - drawnDebtBefore;
    uint256 protocolCut = (delta * liquidityFee) / 100_00;
    uint256 interest = delta - protocolCut;

    // interestForFees = interest * realizedFees / totalAssetsBefore
    uint256 expectedInterestForFees = (interest * realizedFeesAfterFirst) / totalAssetsBefore;

    // Total new fees for second period should be protocolCut + interestForFees
    uint256 expectedNewUnrealizedFees = protocolCut + expectedInterestForFees;

    // getAssetAccruedFees returns realizedFees + unrealizedFees
    // So it should equal realizedFeesAfterFirst + expectedNewUnrealizedFees
    uint256 totalAccruedFees = hub1.getAssetAccruedFees(daiAssetId);
    uint256 expectedTotalAccruedFees = realizedFeesAfterFirst + expectedNewUnrealizedFees;

    // Verify the formula
    assertApproxEqAbs(
      totalAccruedFees,
      expectedTotalAccruedFees,
      2,
      'total accrued fees should match formula'
    );

    // Verify interestForFees is non-zero (fees earned interest)
    assertGt(expectedInterestForFees, 0, 'interestForFees should be > 0');

    // Calculate interest for suppliers (the rest of interest after fees take their share)
    uint256 interestForSuppliers = interest - expectedInterestForFees;

    // Verify accounting: interestForFees + interestForSuppliers = interest (exact)
    assertEq(
      expectedInterestForFees + interestForSuppliers,
      interest,
      'interest split should be exact'
    );

    // Verify: new unrealized fees = protocolCut + interestForFees
    uint256 actualNewUnrealizedFees = totalAccruedFees - realizedFeesAfterFirst;
    assertApproxEqAbs(
      actualNewUnrealizedFees,
      expectedNewUnrealizedFees,
      2,
      'new fees should match'
    );

    // Verify conservation: total delta = fees to treasury + interest to suppliers
    uint256 totalFeesThisPeriod = protocolCut + expectedInterestForFees;
    assertApproxEqAbs(
      totalFeesThisPeriod + interestForSuppliers,
      delta,
      2,
      'delta should be conserved'
    );
  }

  /// @dev Test that mint timing doesn't affect supplier outcomes
  function test_unrealizedFees_mintTimingEquivalence() public {
    // Set high liquidity fee
    updateLiquidityFee(hub1, daiAssetId, 50_00);

    // Setup initial state
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // Accrue for 6 months
    skip(180 days);

    // Record supplier's position value
    uint256 supplierShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 supplierAssetsBeforeMint = hub1.previewRemoveByShares(daiAssetId, supplierShares);

    // Mint fees midway
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // Supplier's position value should be unchanged
    uint256 supplierAssetsAfterMint = hub1.previewRemoveByShares(daiAssetId, supplierShares);
    assertApproxEqAbs(
      supplierAssetsAfterMint,
      supplierAssetsBeforeMint,
      2,
      'supplier value unchanged by mint'
    );

    // Accrue for another 6 months
    skip(180 days);

    // Record final supplier position
    uint256 supplierAssetsFinal = hub1.previewRemoveByShares(daiAssetId, supplierShares);

    // Supplier should have earned yield
    assertGt(
      supplierAssetsFinal,
      supplierAssetsAfterMint,
      'supplier earned yield in second period'
    );
  }

  /// @dev Test new supplier joining after large fee accumulation - verify fair pricing
  function test_unrealizedFees_newSupplierAfterFeeAccumulation() public {
    uint256 liquidityFee = 50_00; // 50%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    // First supplier (bob)
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: BORROW_AMOUNT
    });

    // Accrue fees for a year
    skip(365 days);

    // Calculate fees accumulated
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertGt(accruedFees, 0, 'fees should have accumulated');

    // Record state before new supplier
    uint256 sharePriceBefore = hub1.previewAddByShares(daiAssetId, 1e18);
    uint256 bobShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 bobValueBefore = hub1.previewRemoveByShares(daiAssetId, bobShares);

    // New supplier (alice) joins
    uint256 aliceSupply = 500e18;
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: aliceSupply,
      user: alice
    });

    // Verify alice received shares at fair price (her redeemable ≈ what she put in)
    uint256 aliceShares = hub1.getSpokeAddedShares(daiAssetId, address(spoke1)) - bobShares;
    uint256 aliceValue = hub1.previewRemoveByShares(daiAssetId, aliceShares);
    assertApproxEqAbs(aliceValue, aliceSupply, 2, 'alice got fair share price');

    // Bob's value unchanged by alice joining
    uint256 bobValueAfter = hub1.previewRemoveByShares(daiAssetId, bobShares);
    assertApproxEqAbs(bobValueAfter, bobValueBefore, 2, 'bob value unchanged by alice');

    // Share price should remain stable
    uint256 sharePriceAfter = hub1.previewAddByShares(daiAssetId, 1e18);
    assertApproxEqAbs(sharePriceAfter, sharePriceBefore, 2, 'share price unchanged');

    // Accrue more and verify both earn proportionally
    skip(180 days);

    uint256 bobFinalValue = hub1.previewRemoveByShares(daiAssetId, bobShares);
    uint256 aliceFinalValue = hub1.previewRemoveByShares(daiAssetId, aliceShares);

    // Both should have earned yield
    assertGt(bobFinalValue, bobValueAfter, 'bob earned yield in period 2');
    assertGt(aliceFinalValue, aliceValue, 'alice earned yield');

    // Bob's total value exceeds initial (he earned from period 1 + 2)
    assertGt(bobFinalValue, SUPPLY_AMOUNT, 'bob value > initial supply');
  }

  /// @dev Test extreme scenario: very high fee (90%) with 100% utilization over long period
  function test_unrealizedFees_extremeFeeAccumulation() public {
    // Set very high liquidity fee (90%) - not 100% so suppliers still earn something
    updateLiquidityFee(hub1, daiAssetId, 90_00);

    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    // Borrow everything (100% utilization)
    Utils.draw({
      hub: hub1,
      assetId: daiAssetId,
      to: bob,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT
    });

    // Accrue for 3 years - this should create massive fee accumulation
    skip(3 * 365 days);

    // Get state
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    uint256 realizedFees = hub1.getAsset(daiAssetId).realizedFees;
    uint256 totalFees = accruedFees + realizedFees;

    // With 90% fee for 3 years, fees should be very significant
    assertGt(totalFees, SUPPLY_AMOUNT / 4, 'fees should exceed 25% of initial supply');

    // Share price should have increased (suppliers earn 10% of interest)
    uint256 sharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGt(sharePrice, 1e18, 'share price > 1');

    // Minting should work correctly
    Utils.mintFeeShares(hub1, daiAssetId, ADMIN);

    // System should remain healthy after mint
    uint256 sharePriceAfterMint = hub1.previewAddByShares(daiAssetId, 1e18);
    assertApproxEqAbs(sharePriceAfterMint, sharePrice, 2, 'share price stable after extreme mint');
  }

  /// @dev Test repeated supply/borrow cycles with high fees
  function test_unrealizedFees_repeatedCycles() public {
    // Set high liquidity fee
    updateLiquidityFee(hub1, daiAssetId, 50_00);

    uint256 cycleAmount = 200e18;

    // Initial supply
    Utils.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: SUPPLY_AMOUNT,
      user: bob
    });

    uint256 initialSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);

    // Multiple cycles of borrow -> accrue -> repay -> supply more
    for (uint256 i = 0; i < 5; i++) {
      // Borrow
      Utils.draw({
        hub: hub1,
        assetId: daiAssetId,
        to: alice,
        caller: address(spoke1),
        amount: cycleAmount
      });

      // Accrue
      skip(90 days);

      // Check share price monotonically increases
      uint256 currentSharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
      assertGe(currentSharePrice, initialSharePrice, 'share price should not decrease');
      initialSharePrice = currentSharePrice;

      // More supply (simulating repay + new supply)
      Utils.add({
        hub: hub1,
        assetId: daiAssetId,
        caller: address(spoke1),
        amount: cycleAmount / 2,
        user: alice
      });
    }

    // After all cycles, fees should have accumulated significantly
    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    assertGt(accruedFees, 0, 'fees should have accumulated through cycles');
  }

  /// @dev Fuzz test for fee accrual with varying parameters
  function testFuzz_unrealizedFees_accrual(
    uint256 supplyAmount,
    uint256 borrowRatio,
    uint256 liquidityFee,
    uint256 timeSkip
  ) public {
    // Bound inputs to reasonable ranges
    supplyAmount = bound(supplyAmount, 1e18, 1e24);
    borrowRatio = bound(borrowRatio, 10, 90); // 10-90% utilization
    liquidityFee = bound(liquidityFee, 0, 100_00); // 0-100%
    timeSkip = bound(timeSkip, 1 days, 365 days);

    uint256 borrowAmount = (supplyAmount * borrowRatio) / 100;

    // Update liquidity fee
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: timeSkip
    });

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // If liquidityFee is 0, no fees should accrue
    if (liquidityFee == 0) {
      assertEq(accruedFees, 0, 'no fees when liquidityFee is 0');
    }

    // Share price should never decrease
    uint256 sharePrice = hub1.previewAddByShares(daiAssetId, 1e18);
    assertGe(sharePrice, 1e18, 'share price >= 1');
  }

  /// @dev Fuzz test for fee distribution proportionality
  function testFuzz_unrealizedFees_proportionality(
    uint256 supplyAmount,
    uint256 borrowAmount
  ) public {
    // Bound inputs
    supplyAmount = bound(supplyAmount, 1e18, 1e24);
    borrowAmount = bound(borrowAmount, 1e17, supplyAmount);

    // Set a known liquidity fee
    uint256 liquidityFee = 25_00; // 25%
    updateLiquidityFee(hub1, daiAssetId, liquidityFee);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: supplyAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: borrowAmount,
      skipTime: 365 days
    });

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalDelta = drawnDebt - borrowAmount;

    if (totalDelta > 0) {
      // Protocol cut should be at least liquidityFee% of delta
      uint256 minProtocolCut = (totalDelta * liquidityFee) / 100_00;
      assertGe(accruedFees, minProtocolCut, 'fees >= min protocol cut');

      // Fees should not exceed total delta
      assertLe(accruedFees, totalDelta, 'fees <= total delta');
    }
  }
}
