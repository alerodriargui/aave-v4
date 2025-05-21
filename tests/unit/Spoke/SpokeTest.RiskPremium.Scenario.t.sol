// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';

contract SpokeRiskPremiumScenarioTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  struct GeneralLocalVars {
    uint256 usdxSupplyAmount;
    uint256 wethSupplyAmount;
    uint256 wbtcSupplyAmount;
    uint256 daiBorrowAmount;
    uint256 daiBorrowSpoke1;
    uint256 usdxBorrowSpoke2;
    uint40 lastUpdateTimestamp;
    uint256 delay;
  }

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();
  }

  /** Spoke1 Init Config
   * +-----------+------------+------------------+--------+----------+
   * | reserveId | collateral | liquidityPremium | price  | decimals |
   * +-----------+------------+------------------+--------+----------+
   * |         0 | weth       | 15%              | 2_000  |       18 |
   * |         1 | wbtc       | 50%              | 50_000 |        8 |
   * |         2 | dai        | 20%              | 1      |       18 |
   * |         3 | usdx       | 50%              | 1      |        6 |
   * +-----------+------------+------------------+--------+----------+
   */
  function test_riskPremiumPropagatesCorrectly_singleBorrow() public {
    GeneralLocalVars memory vars;
    vars.usdxSupplyAmount = 1500e6; // 1500 usd, 50 lp
    vars.wethSupplyAmount = 5e18; // 10_000 usd, 15 lp
    vars.daiBorrowAmount = 10_000e18; // 10_000 usd, 20 lp
    vars.delay = 365 days;
    test_fuzz_riskPremiumPropagatesCorrectly_singleBorrow(vars);
  }

  function test_fuzz_riskPremiumPropagatesCorrectly_singleBorrow(
    GeneralLocalVars memory vars
  ) public {
    vars.daiBorrowAmount = bound(vars.daiBorrowAmount, 1e18, 1e25);
    vars.wethSupplyAmount = bound(vars.wethSupplyAmount, vars.daiBorrowAmount / 2_000, 1e25);
    vars.usdxSupplyAmount = bound(vars.daiBorrowAmount, 1e6, 1e15);
    vars.delay = bound(vars.delay, 1 days, 10_000 days);

    vm.prank(bob);
    spoke1.supply(_daiReserveId(spoke1), vars.daiBorrowAmount);

    vm.startPrank(alice);
    spoke1.supply(_usdxReserveId(spoke1), vars.usdxSupplyAmount);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true);

    spoke1.supply(_wethReserveId(spoke1), vars.wethSupplyAmount);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true);

    spoke1.borrow(_daiReserveId(spoke1), vars.daiBorrowAmount, alice);
    vm.stopPrank();

    uint256 usdxLiquidityPremium = spoke1
      .getReserve(_usdxReserveId(spoke1))
      .config
      .liquidityPremium;
    uint256 wethLiquidityPremium = spoke1
      .getReserve(_wethReserveId(spoke1))
      .config
      .liquidityPremium;
    assertLt(wethLiquidityPremium, usdxLiquidityPremium);
    // weth is enough to cover debt, both stored & calc value match
    assertEq(spoke1.getUserRiskPremium(alice), wethLiquidityPremium);
    assertEq(spoke1.getLastUsedUserRiskPremium(alice), wethLiquidityPremium);

    // spoke risk premium should match since there is only 1 debt for dai
    assertEq(spoke1.getReserveRiskPremium(_daiReserveId(spoke1)), wethLiquidityPremium);
    // propagated correctly on hub, should match this spoke's reserve since it's the only
    // spoke drawing dai
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), wethLiquidityPremium);

    vars.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(vars.delay);

    // since only DAI is borrowed in the system, supply interest is accrued only on it
    assertEq(spoke1.getSuppliedAmount(_usdxReserveId(spoke1), alice), vars.usdxSupplyAmount);
    assertEq(spoke1.getSuppliedAmount(_wethReserveId(spoke1), alice), vars.wethSupplyAmount);

    uint256 accruedDaiDebt = vars.daiBorrowAmount.rayMul(
      MathUtils.calculateLinearInterest(
        hub.getBaseInterestRate(daiAssetId), // note: IR strategy has a pending fix
        vars.lastUpdateTimestamp
      ) - WadRayMath.RAY
    );
    uint256 expectedOutstandingPremium = accruedDaiDebt.percentMul(wethLiquidityPremium);

    (uint256 baseDaiDebt, uint256 outstandingDaiPremium) = spoke1.getUserDebt(
      _daiReserveId(spoke1),
      alice
    );
    assertEq(baseDaiDebt, vars.daiBorrowAmount + accruedDaiDebt);
    assertEq(outstandingDaiPremium, expectedOutstandingPremium);
    vars.daiBorrowAmount += accruedDaiDebt;

    // now since debt has grown, weth supply is not enough to cover debt, hence rp changes
    uint256 remainingDaiDebt = accruedDaiDebt + outstandingDaiPremium;
    // usdx is enough to cover remaining debt
    assertLt(
      _getValueInBaseCurrency(daiAssetId, remainingDaiDebt),
      _getValueInBaseCurrency(usdxAssetId, vars.usdxSupplyAmount)
    );

    uint256 newLiquidityPremium = (_getValueInBaseCurrency(wethAssetId, vars.wethSupplyAmount) *
      wethLiquidityPremium +
      _getValueInBaseCurrency(daiAssetId, remainingDaiDebt) *
      usdxLiquidityPremium) /
      (_getValueInBaseCurrency(wethAssetId, vars.wethSupplyAmount) +
        _getValueInBaseCurrency(daiAssetId, remainingDaiDebt));

    assertApproxEqAbs(spoke1.getUserRiskPremium(alice), newLiquidityPremium, 2);
    // last stored remains the same
    assertApproxEqAbs(spoke1.getLastUsedUserRiskPremium(alice), wethLiquidityPremium, 1);

    // we supply more usdx which should trigger stored value update for risk premium, *and accrue* dai debt
    // (this will be checked implicitly through having correct outstanding premium accrual after delay)
    vm.prank(alice);
    spoke1.supply(_usdxReserveId(spoke1), 500e6);

    assertApproxEqAbs(spoke1.getLastUsedUserRiskPremium(alice), newLiquidityPremium, 2);
    assertApproxEqAbs(spoke1.getUserRiskPremium(alice), newLiquidityPremium, 2);
    // spoke's risk premium should still match since we only have alice's debt in system
    assertApproxEqAbs(spoke1.getReserveRiskPremium(_daiReserveId(spoke1)), newLiquidityPremium, 2);
    assertApproxEqAbs(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), newLiquidityPremium, 2);

    vars.lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(vars.delay);

    // now we supply more weth such that new total debt from now on is covered by weth
    vm.prank(alice);
    spoke1.supply(_wethReserveId(spoke1), vars.wethSupplyAmount);

    accruedDaiDebt = vars.daiBorrowAmount.rayMul(
      MathUtils.calculateLinearInterest(
        hub.getBaseInterestRate(daiAssetId), // note: IR strategy has a pending fix
        vars.lastUpdateTimestamp
      ) - WadRayMath.RAY
    );
    expectedOutstandingPremium += accruedDaiDebt.percentMul(newLiquidityPremium);

    (baseDaiDebt, outstandingDaiPremium) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);
    assertApproxEqRel(baseDaiDebt, vars.daiBorrowAmount + accruedDaiDebt, 0.001e18);
    assertApproxEqRel(outstandingDaiPremium, expectedOutstandingPremium, 0.001e18);

    vm.prank(alice);
    spoke1.repay(_daiReserveId(spoke1), baseDaiDebt + outstandingDaiPremium);

    (baseDaiDebt, outstandingDaiPremium) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);
    assertEq(baseDaiDebt, 0);
    assertEq(outstandingDaiPremium, 0);
    (baseDaiDebt, outstandingDaiPremium) = spoke1.getReserveDebt(_daiReserveId(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(outstandingDaiPremium, 0);
    (baseDaiDebt, outstandingDaiPremium) = hub.getSpokeDebt(daiAssetId, address(spoke1));
    assertEq(baseDaiDebt, 0);
    assertEq(outstandingDaiPremium, 0);

    assertEq(spoke1.getUserRiskPremium(alice), 0);
    assertEq(spoke1.getLastUsedUserRiskPremium(alice), 0);
    assertEq(spoke1.getReserveRiskPremium(_daiReserveId(spoke1)), 0);
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), 0);
  }

  function test_riskPremiumMultiSpoke() public {
    GeneralLocalVars memory vars;

    // Spoke1 Config: WETH (15%), USDX (50%), DAI (20%)
    // Spoke2 Config: WBTC (50%), usdx (30%), DAI (25%)

    // Collateral Supplies
    vars.wethSupplyAmount = 5e18; // 5 ETH @ $2,000 = $10,000 (Spoke1)
    vars.usdxSupplyAmount = 1500e6; // 1,500 USDX @ $1 = $1,500 (Spoke1)
    vars.wbtcSupplyAmount = 0.2e8; // 0.2 WBTC @ $50,000 = $10,000 (Spoke2)
    vars.usdxSupplyAmount = 1000e6; // 1,000 usdx @ $1 = $1,000 (Spoke2)

    // Borrow Amounts
    vars.daiBorrowSpoke1 = 10_000e18; // $10,000 DAI from Spoke1
    vars.usdxBorrowSpoke2 = 5_000e6; // $5,000 USDX from Spoke2

    // Supply collateral to Spoke1
    vm.startPrank(alice);
    spoke1.supply(_wethReserveId(spoke1), vars.wethSupplyAmount);
    spoke1.setUsingAsCollateral(_wethReserveId(spoke1), true);
    spoke1.supply(_usdxReserveId(spoke1), vars.usdxSupplyAmount);
    spoke1.setUsingAsCollateral(_usdxReserveId(spoke1), true);

    // Supply collateral to Spoke2
    spoke2.supply(_wbtcReserveId(spoke2), vars.wbtcSupplyAmount);
    spoke2.setUsingAsCollateral(_wbtcReserveId(spoke2), true);
    spoke2.supply(_usdxReserveId(spoke2), vars.usdxSupplyAmount);
    spoke2.setUsingAsCollateral(_usdxReserveId(spoke2), true);
    vm.stopPrank();

    // Borrow from both spokes
    vm.prank(alice);
    spoke1.borrow(_daiReserveId(spoke1), vars.daiBorrowSpoke1, alice);
    vm.prank(alice);
    spoke2.borrow(_usdxReserveId(spoke2), vars.usdxBorrowSpoke2, alice);

    // --- Check initial risk premiums ---
    // Spoke1: WETH covers full DAI debt (15%)
    assertEq(spoke1.getUserRiskPremium(alice), 15e16, 'Spoke1 User RP');
    assertEq(spoke1.getReserveRiskPremium(_daiReserveId(spoke1)), 15e16, 'Spoke1 DAI RP');

    // Spoke2: usdx (30%) covers $1k, WBTC (50%) covers $4k → 46% avg
    uint256 spoke2ExpectedRP = (1_000e18 * 30e16 + 4_000e18 * 50e16) / 5_000e18;
    assertEq(spoke2.getUserRiskPremium(alice), spoke2ExpectedRP, 'Spoke2 User RP');
    assertEq(
      spoke2.getReserveRiskPremium(_usdxReserveId(spoke2)),
      spoke2ExpectedRP,
      'Spoke2 USDX RP'
    );

    // Hub aggregation checks
    // DAI: Only Spoke1 has debt → 15%
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), 15e16, 'Hub Spoke1 DAI RP');
    // USDX: Only Spoke2 has debt → 46%
    assertEq(
      hub.getSpokeRiskPremium(usdxAssetId, address(spoke2)),
      spoke2ExpectedRP,
      'Hub Spoke2 USDX RP'
    );

    // --- Accrue interest and check updates ---
    vars.delay = 365 days;
    skip(vars.delay);

    // Check new premiums after debt growth
    // Spoke1: Debt increases but WETH still sufficient (RP remains 15%)
    // Spoke2: Debt increases, check if collateral coverage changes

    // --- Repay all debts ---
    vm.startPrank(alice);
    // Repay Spoke1 DAI debt
    (uint256 baseDebt1, uint256 premium1) = spoke1.getUserDebt(_daiReserveId(spoke1), alice);
    spoke1.repay(_daiReserveId(spoke1), baseDebt1 + premium1);

    // Repay Spoke2 USDX debt
    (uint256 baseDebt2, uint256 premium2) = spoke2.getUserDebt(_usdxReserveId(spoke2), alice);
    spoke2.repay(_usdxReserveId(spoke2), baseDebt2 + premium2);
    vm.stopPrank();

    // Verify all risk premiums reset
    assertEq(spoke1.getUserRiskPremium(alice), 0, 'Spoke1 User RP After Repay');
    assertEq(spoke2.getUserRiskPremium(alice), 0, 'Spoke2 User RP After Repay');
    assertEq(spoke1.getReserveRiskPremium(_daiReserveId(spoke1)), 0, 'Spoke1 DAI RP After Repay');
    assertEq(spoke2.getReserveRiskPremium(_usdxReserveId(spoke2)), 0, 'Spoke2 USDX RP After Repay');
    assertEq(hub.getSpokeRiskPremium(daiAssetId, address(spoke1)), 0, 'Hub DAI RP After Repay');
    assertEq(hub.getSpokeRiskPremium(usdxAssetId, address(spoke2)), 0, 'Hub USDX RP After Repay');
  }

  function _usdxReserveId(Spoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].usdx.reserveId;
  }
  function _daiReserveId(Spoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].dai.reserveId;
  }

  function _wethReserveId(Spoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].weth.reserveId;
  }

  function _wbtcReserveId(Spoke spoke) internal view returns (uint256) {
    return spokeInfo[spoke].wbtc.reserveId;
  }

  function _getValueInBaseCurrency(
    uint256 assetId,
    uint256 amount
  ) internal view returns (uint256) {
    return (amount * oracle.getAssetPrice(assetId)) / 10 ** hub.getAsset(assetId).config.decimals;
  }
}
