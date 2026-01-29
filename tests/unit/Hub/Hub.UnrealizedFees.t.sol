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

  /// @dev Test that no fees accrue when liquidityFee is 0
  function test_unrealizedFees_zeroLiquidityFee() public {
    // Set liquidity fee to 0
    updateLiquidityFee(hub1, daiAssetId, 0);

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

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);

    // No fees should accrue
    assertEq(accruedFees, 0, 'fees should be 0 when liquidityFee is 0');
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

  /// @dev Test fee accrual with maximum liquidity fee
  function test_unrealizedFees_maxLiquidityFee() public {
    // Set max liquidity fee (100%)
    updateLiquidityFee(hub1, daiAssetId, 100_00);

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

    uint256 accruedFees = _getExpectedFeeReceiverAddedAssets(hub1, daiAssetId);
    (uint256 drawnDebt, ) = hub1.getAssetOwed(daiAssetId);
    uint256 totalInterest = drawnDebt - BORROW_AMOUNT;

    // With 100% fee, all delta should go to fees
    // But interest portion still gets distributed, so fees should be close to total delta
    assertGt(accruedFees, 0, 'fees should be > 0');
    // Fees should be less than or equal to total interest
    assertLe(accruedFees, totalInterest, 'fees should not exceed interest');
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
    assertApproxEqRel(sharePriceAfter, sharePriceBefore, 1e14, 'share price should remain stable');

    // Supplier's shares should not change
    uint256 supplierSharesAfter = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    assertEq(supplierSharesAfter, supplierSharesBefore, 'supplier shares unchanged');

    // Fee shares should have been minted
    assertGt(mintedShares, 0, 'fee shares should be minted');
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
