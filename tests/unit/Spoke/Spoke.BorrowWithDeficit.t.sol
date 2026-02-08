// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeBorrowWithDeficitTest is SpokeBase {
  uint256 daiReserveId;
  uint256 usdyReserveId;

  address liquidator;

  function setUp() public override {
    super.setUp();

    _updateLiquidationConfig(
      spoke1,
      ISpoke.LiquidationConfig({
        targetHealthFactor: 2e18,
        healthFactorForMaxBonus: 0,
        liquidationBonusFactor: 0
      })
    );

    daiReserveId = _daiReserveId(spoke1);
    usdyReserveId = _usdyReserveId(spoke1);

    _updateMaxLiquidationBonus(spoke1, daiReserveId, 100_00);
    _updateLiquidationFee(spoke1, daiReserveId, 100_00);

    _openSupplyPosition(spoke1, daiReserveId, 1e10);
    _openSupplyPosition(spoke1, usdyReserveId, 1e10);

    liquidator = bob;
  }

  /// borrow with 2 wei collateral, 1 wei debt
  function test_borrowWithDeficit_scenario1() public {
    vm.startPrank(alice);
    spoke1.supply(_usdyReserveId(spoke1), 2, alice);
    spoke1.setUsingAsCollateral(_usdyReserveId(spoke1), true, alice);
    spoke1.borrow(daiReserveId, 1, alice);
    vm.stopPrank();

    _testBorrowWithDeficit();
  }

  /// borrow with 1.5 wei worth of collateral, 1 wei debt
  function test_borrowWithDeficit_scenario2() public {
    _mockReservePrice(spoke1, usdyReserveId, 1.5e8); // USDY worth $1.50

    vm.startPrank(alice);
    spoke1.supply(_usdyReserveId(spoke1), 1, alice);
    spoke1.setUsingAsCollateral(_usdyReserveId(spoke1), true, alice);
    spoke1.borrow(daiReserveId, 1, alice);
    vm.stopPrank();

    _testBorrowWithDeficit();
  }

  function _testBorrowWithDeficit() internal {
    console.log('---- after borrow ----');
    console.log(' alice health factor %e', _getUserHealthFactor(spoke1, alice));
    console.log(' alice dai debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
    console.log(
      ' alice usdy collateral %e',
      spoke1.getUserSuppliedAssets(_usdyReserveId(spoke1), alice)
    );

    // skip 1 block to accumulate debt interest
    skip(1);

    console.log('---- before liquidation ----');
    console.log(' alice dai debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
    console.log(' alice health factor %e', _getUserHealthFactor(spoke1, alice));
    console.log(
      ' alice usdy collateral %e',
      spoke1.getUserSuppliedAssets(_usdyReserveId(spoke1), alice)
    );

    uint256 liquidatorDaiBalanceBefore = tokenList.dai.balanceOf(liquidator);
    uint256 liquidatorUsdyBalanceBefore = tokenList.usdy.balanceOf(liquidator);

    // no deficit initially
    assertEq(hub1.getAssetDeficitRay(daiAssetId), 0);
    assertEq(hub1.getAssetDeficitRay(usdyAssetId), 0);

    // deficit not reported
    vm.expectCall(address(hub1), abi.encodeWithSelector(IHubBase.reportDeficit.selector), 0);

    vm.prank(liquidator);
    spoke1.liquidationCall(usdyReserveId, daiReserveId, alice, UINT256_MAX, false);

    uint256 liquidatorDaiBalanceAfter = tokenList.dai.balanceOf(liquidator);
    uint256 liquidatorUsdyBalanceAfter = tokenList.usdy.balanceOf(liquidator);

    // no deficit created
    assertEq(hub1.getAssetDeficitRay(daiAssetId), 0);
    assertEq(hub1.getAssetDeficitRay(usdyAssetId), 0);

    console.log('---- after liquidation ----');
    console.log(' alice dai debt %e', spoke1.getUserTotalDebt(daiReserveId, alice));
    console.log(
      ' alice usdy collateral %e',
      spoke1.getUserSuppliedAssets(_usdyReserveId(spoke1), alice)
    );
    console.log(
      ' liquidator dai balance change %e',
      stdMath.delta(liquidatorDaiBalanceAfter, liquidatorDaiBalanceBefore)
    );
    console.log(
      ' liquidator usdy balance change %e',
      stdMath.delta(liquidatorUsdyBalanceAfter, liquidatorUsdyBalanceBefore)
    );
  }
}
