// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SupplyRepayPositionManagerTest is SpokeBase {
  ISpoke public spoke;
  SupplyRepayPositionManager public positionManager;
  TestReturnValues public returnValues;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    spoke = spoke1;
    positionManager = new SupplyRepayPositionManager(address(spoke));

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke.setUserPositionManager(address(positionManager), true);
  }

  function test_supplyOnBehalfOf() public {
    test_supplyOnBehalfOf_fuzz(100e18);
  }

  function test_supplyOnBehalfOf_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_DAI);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), amount);

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice);
    uint256 prevCallerSuppliedAmount = spoke.getUserSuppliedAssets(_daiReserveId(spoke), bob);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Supply(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      hub1.previewAddByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.supplyOnBehalfOf(
      _daiReserveId(spoke),
      amount,
      alice
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewAddByAssets(daiAssetId, amount));

    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(bob), prevCallerBalance - amount);
    assertEq(
      spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice),
      prevUserSuppliedAmount + amount
    );
    assertEq(spoke.getUserSuppliedAssets(_daiReserveId(spoke), bob), prevCallerSuppliedAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance + amount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_supplyOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.supplyOnBehalfOf(reserveId, 100e18, alice);
  }

  function test_repayOnBehalfOf() public {
    test_repayOnBehalfOf_fuzz(50e18);
  }

  function test_repayOnBehalfOf_fuzz(uint256 repayAmount) public {
    uint256 aliceSupplyAmount = 1000e18;
    uint256 bobSupplyAmount = 150e18;
    uint256 borrowAmount = 100e18;
    repayAmount = bound(repayAmount, 1, borrowAmount);

    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, aliceSupplyAmount, alice);
    Utils.supply(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    Utils.borrow(spoke, _daiReserveId(spoke), alice, borrowAmount, alice);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), repayAmount);

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(
      _daiReserveId(spoke),
      alice
    );
    (uint256 baseRestored, ) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      daiAssetId
    );
    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke,
      alice,
      _daiReserveId(spoke),
      repayAmount
    );

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      repayAmount,
      expectedPremiumDelta
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.repayOnBehalfOf(
      _daiReserveId(spoke),
      repayAmount,
      alice
    );

    (userDrawnDebt, userPremiumDebt) = spoke.getUserDebt(_daiReserveId(spoke), alice);

    assertEq(returnValues.amount, repayAmount);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount - repayAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance + repayAmount);
    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(bob), prevCallerBalance - repayAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_repayOnBehalfOf_fuzz_withInterest(uint256 repayAmount, uint256 elapsedTime) public {
    uint256 borrowAmount = 100e18;
    repayAmount = bound(repayAmount, borrowAmount, borrowAmount * 10);
    elapsedTime = bound(elapsedTime, 100 days, 400 days);

    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, 1000e18, alice);
    Utils.supply(spoke, _daiReserveId(spoke), bob, 150e18, bob);
    Utils.borrow(spoke, _daiReserveId(spoke), alice, borrowAmount, alice);

    skip(elapsedTime);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), repayAmount);

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(
      _daiReserveId(spoke),
      alice
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      daiAssetId
    );

    {
      IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
        spoke,
        alice,
        _daiReserveId(spoke),
        repayAmount
      );
      uint256 repaidAmount = _min(userDrawnDebt + userPremiumDebt, repayAmount);
      vm.expectEmit(address(spoke));
      emit ISpokeBase.Repay(
        _daiReserveId(spoke),
        address(positionManager),
        alice,
        hub1.previewRestoreByAssets(daiAssetId, baseRestored),
        repaidAmount,
        expectedPremiumDelta
      );
      vm.prank(bob);
      (returnValues.shares, returnValues.amount) = positionManager.repayOnBehalfOf(
        _daiReserveId(spoke),
        repayAmount,
        alice
      );

      assertApproxEqAbs(returnValues.amount, baseRestored + premiumRestored, 1);
      assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));
    }

    (uint256 newUserDrawnDebt, uint256 newUserPremiumDebt) = spoke.getUserDebt(
      _daiReserveId(spoke),
      alice
    );

    assertApproxEqAbs(
      newUserDrawnDebt + newUserPremiumDebt,
      userDrawnDebt + userPremiumDebt - (baseRestored + premiumRestored),
      2
    );
    assertApproxEqAbs(
      tokenList.dai.balanceOf(address(hub1)),
      prevHubBalance + (baseRestored + premiumRestored),
      2
    );
    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertApproxEqAbs(
      tokenList.dai.balanceOf(bob),
      prevCallerBalance - (baseRestored + premiumRestored),
      1
    );
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_repayOnBehalfOf_excessAmount() public {
    uint256 aliceSupplyAmount = 1000e18;
    uint256 bobSupplyAmount = 150e18;
    uint256 borrowAmount = 100e18;
    uint256 repayAmount = 150e18;

    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, aliceSupplyAmount, alice);
    Utils.supply(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);
    Utils.borrow(spoke, _daiReserveId(spoke), alice, borrowAmount, alice);

    skip(322 days);

    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), repayAmount);

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(
      _daiReserveId(spoke),
      alice
    );
    (uint256 baseRestored, uint256 premiumRestored) = _calculateExactRestoreAmount(
      userDrawnDebt,
      userPremiumDebt,
      repayAmount,
      daiAssetId
    );
    uint256 totalRepaid = baseRestored + premiumRestored;
    IHubBase.PremiumDelta memory expectedPremiumDelta = _getExpectedPremiumDeltaForRestore(
      spoke,
      alice,
      _daiReserveId(spoke),
      repayAmount
    );

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Repay(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, baseRestored),
      totalRepaid,
      expectedPremiumDelta
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.repayOnBehalfOf(
      _daiReserveId(spoke),
      repayAmount,
      alice
    );

    (userDrawnDebt, userPremiumDebt) = spoke.getUserDebt(_daiReserveId(spoke), alice);

    assertEq(returnValues.amount, baseRestored + premiumRestored);
    assertEq(returnValues.shares, hub1.previewRestoreByAssets(daiAssetId, baseRestored));

    assertEq(userDrawnDebt + userPremiumDebt, 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance + totalRepaid);
    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(bob), prevCallerBalance - totalRepaid);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
  }

  function test_repayOnBehalfOfrevertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.repayOnBehalfOf(reserveId, 100e18, alice);
  }
}
