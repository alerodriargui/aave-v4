// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

struct TestDrawAmountInput {
  uint256 spoke1;
  uint256 spoke2;
  uint256 spoke3;
}

struct TestRiskPremiumRayInput {
  uint256 spoke1;
  uint256 spoke2;
  uint256 spoke3;
}

struct TestDrawAmountAndRiskPremiumRayInput {
  TestDrawAmountInput drawAmount;
  TestRiskPremiumRayInput riskPremiumRay;
}

contract LiquidityHubRiskPremiumTest_Base is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  // todo: move to base test after conflict resolution
  uint256 internal daiAssetId = 2;
  uint256 internal wbtcAssetId = 3;

  uint256 daiAmount = 2000e18;
  uint256 wethAmount = 1e18;

  uint256 spoke1RiskPremiumRay = uint256(50_00).bpsToRay();
  uint256 spoke2RiskPremiumRay = uint256(20_00).bpsToRay();
  uint256 spoke3RiskPremiumRay = uint256(30_00).bpsToRay();

  function setUp() public override {
    super.setUp();
    initEnvironment();
  }

  function bound(
    TestDrawAmountAndRiskPremiumRayInput memory input,
    uint256 minDrawAmount,
    uint256 maxDrawAmount
  ) internal pure returns (TestDrawAmountAndRiskPremiumRayInput memory) {
    input.drawAmount.spoke1 = bound(input.drawAmount.spoke1, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke2 = bound(input.drawAmount.spoke2, minDrawAmount, maxDrawAmount);
    input.drawAmount.spoke3 = bound(input.drawAmount.spoke3, minDrawAmount, maxDrawAmount);

    uint256 maxRiskPremiumRay = PercentageMath.PERCENTAGE_FACTOR.bpsToRay();
    input.riskPremiumRay.spoke1 = bound(input.riskPremiumRay.spoke1, 0, maxRiskPremiumRay);
    input.riskPremiumRay.spoke2 = bound(input.riskPremiumRay.spoke2, 0, maxRiskPremiumRay);
    input.riskPremiumRay.spoke3 = bound(input.riskPremiumRay.spoke3, 0, maxRiskPremiumRay);

    vm.assume(input.drawAmount.spoke1 + input.drawAmount.spoke2 + input.drawAmount.spoke3 != 0);

    return input;
  }
}

contract LiquidityHubRiskPremium_ConstantTimeAndRiskPremium is LiquidityHubRiskPremiumTest_Base {
  using WadRayMath for uint256;

  function test_riskPremiumOnNoDraw() public {
    vm.prank(address(spoke1));
    uint256 spoke1RiskPremiumWeightedSum = 0; // since drawn is zero
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumWeightedSum, alice);
    assertEq(hub.getAssetRiskPremium(daiAssetId), 0); // since no drawn liquidity
  }

  function test_singleDrawSameAmount() public {
    vm.prank(address(spoke1));
    uint256 spoke1RiskPremiumWeightedSum = 0; // since drawn is zero
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumWeightedSum, alice);

    uint256 usdxDrawnAmount = daiAmount / 2;
    uint256 spoke2RiskPremiumWeightedSum = usdxDrawnAmount.rayMul(spoke2RiskPremiumRay);
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke2RiskPremiumWeightedSum);

    assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    assertEq(hub.getAssetRiskPremium(daiAssetId), spoke2RiskPremiumRay);
  }

  function test_multipleDrawSameAmount() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRay, alice);

    uint256 usdxDrawnAmount = daiAmount / 3;
    uint256 spoke2RiskPremiumWeightedSum = usdxDrawnAmount.rayMul(spoke2RiskPremiumRay);
    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke2RiskPremiumWeightedSum);

    assertEq(hub.getAsset(daiAssetId).baseDebt, usdxDrawnAmount);
    assertEq(hub.getAssetRiskPremium(daiAssetId), spoke2RiskPremiumRay);

    // spoke 3 draws
    uint256 spoke3RiskPremiumWeightedSum = usdxDrawnAmount.rayMul(spoke3RiskPremiumRay);
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke3RiskPremiumWeightedSum);

    uint256 totalBaseDebt = usdxDrawnAmount * 2;
    uint256 expectedRiskPremium = (usdxDrawnAmount *
      spoke2RiskPremiumRay +
      usdxDrawnAmount *
      spoke3RiskPremiumRay) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium);

    uint256 spoke1RiskPremiumWeightedSum = usdxDrawnAmount.rayMul(spoke1RiskPremiumRay);
    // spoke 1 draws remaining liquidity
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, usdxDrawnAmount, spoke1RiskPremiumWeightedSum);

    totalBaseDebt = usdxDrawnAmount * 3;
    expectedRiskPremium =
      (usdxDrawnAmount *
        spoke1RiskPremiumRay +
        usdxDrawnAmount *
        spoke2RiskPremiumRay +
        usdxDrawnAmount *
        spoke3RiskPremiumRay) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium);
  }

  function test_multipleDrawMultipleAmount() public {
    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRay, alice);

    uint256 spoke1DrawAmount = daiAmount / 4;
    uint256 spoke2DrawAmount = daiAmount / 2;
    uint256 spoke3DrawAmount = daiAmount / 8;

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, spoke1DrawAmount, spoke1RiskPremiumRay);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAssetRiskPremium(daiAssetId), spoke1RiskPremiumRay);

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, spoke2DrawAmount, spoke2RiskPremiumRay);

    totalBaseDebt += spoke2DrawAmount;
    uint256 expectedRiskPremium = (spoke1DrawAmount *
      spoke1RiskPremiumRay +
      spoke2DrawAmount *
      spoke2RiskPremiumRay) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium);

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, spoke3DrawAmount, spoke3RiskPremiumRay);

    totalBaseDebt += spoke3DrawAmount;
    expectedRiskPremium =
      (spoke1DrawAmount *
        spoke1RiskPremiumRay +
        spoke2DrawAmount *
        spoke2RiskPremiumRay +
        spoke3DrawAmount *
        spoke3RiskPremiumRay) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium);
  }

  function test_fuzzDrawAndPremium(TestDrawAmountAndRiskPremiumRayInput memory p) public {
    p = bound({input: p, minDrawAmount: 1, maxDrawAmount: daiAmount});
    uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, totalToDraw, spoke1RiskPremiumRay, alice);

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke1, p.riskPremiumRay.spoke1);

    uint256 totalBaseDebt = p.drawAmount.spoke1;
    assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    assertEq(hub.getAssetRiskPremium(daiAssetId), p.riskPremiumRay.spoke1);

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke2, p.riskPremiumRay.spoke2);

    totalBaseDebt += p.drawAmount.spoke2;
    uint256 expectedRiskPremium = (p.drawAmount.spoke1 *
      p.riskPremiumRay.spoke1 +
      p.drawAmount.spoke2 *
      p.riskPremiumRay.spoke2) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium, 1);

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke3, p.riskPremiumRay.spoke3);

    totalBaseDebt += p.drawAmount.spoke3;
    expectedRiskPremium =
      (p.drawAmount.spoke1 *
        p.riskPremiumRay.spoke1 +
        p.drawAmount.spoke2 *
        p.riskPremiumRay.spoke2 +
        p.drawAmount.spoke3 *
        p.riskPremiumRay.spoke3) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium, 1);
  }
}

contract LiquidityHubRiskPremium_VariableTimeAndConstantRiskPremium is
  LiquidityHubRiskPremiumTest_Base
{
  using WadRayMath for uint256;

  function test_fuzzMultipleDrawWhileAccruingInterest(
    uint256 timeToSkip,
    uint256 baseBorrowRate
  ) public {
    timeToSkip = bound(timeToSkip, 1 days, 10_000 days);
    baseBorrowRate = bound(baseBorrowRate, uint256(1).bpsToRay(), uint256(100_00).bpsToRay());
    uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRay, alice);

    uint256 spoke1DrawAmount = daiAmount / 4;
    uint256 spoke2DrawAmount = daiAmount / 2;
    uint256 spoke3DrawAmount = daiAmount / 8;

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, spoke1DrawAmount, spoke1RiskPremiumRay);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAssetRiskPremium(daiAssetId), spoke1RiskPremiumRay);

    skip(timeToSkip);
    uint256 spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, spoke2DrawAmount, spoke2RiskPremiumRay); // trigger base debt update

    // debt has been not been accrued for spoke 1 individually yet
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, spoke1DrawAmount);

    totalBaseDebt += spoke1AccruedDebt + spoke2DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    uint256 expectedRiskPremium = ((spoke1DrawAmount + spoke1AccruedDebt) * // correctly account for spoke1 debt
      spoke1RiskPremiumRay +
      spoke2DrawAmount *
      spoke2RiskPremiumRay) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium);

    lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(timeToSkip);

    spoke1DrawAmount += spoke1AccruedDebt;
    spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );
    uint256 spoke2AccruedDebt = spoke2DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, spoke3DrawAmount, spoke3RiskPremiumRay);

    totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + spoke3DrawAmount;
    expectedRiskPremium =
      ((spoke1DrawAmount + spoke1AccruedDebt) *
        spoke1RiskPremiumRay +
        (spoke2DrawAmount + spoke2AccruedDebt) *
        spoke2RiskPremiumRay +
        spoke3DrawAmount *
        spoke3RiskPremiumRay) /
      totalBaseDebt;
    assertApproxEqAbs(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt, 1);
    assertApproxEqAbs(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium, 1);
  }

  function test_multipleDrawWhileAccruingInterest() public {
    test_fuzzMultipleDrawWhileAccruingInterest({
      timeToSkip: 365 days,
      baseBorrowRate: uint256(15_00).bpsToRay()
    });
  }

  function test_multipleDrawWhileAccruingInterestWithChangingRate() public {
    uint256 timeToSkip = 365 days; // todo fuzz this and rate
    uint256 rate = uint256(15_00).bpsToRay();
    uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, daiAmount, spoke1RiskPremiumRay, alice);

    uint256 spoke1DrawAmount = daiAmount / 4;
    uint256 spoke2DrawAmount = daiAmount / 2;
    uint256 spoke3DrawAmount = daiAmount / 8;

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, spoke1DrawAmount, spoke1RiskPremiumRay);

    uint256 totalBaseDebt = spoke1DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, spoke1DrawAmount);
    assertEq(hub.getAssetRiskPremium(daiAssetId), spoke1RiskPremiumRay);

    skip(timeToSkip);
    uint256 spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // borrow rate changes with this action
    rate *= 2;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(rate)
    );

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, spoke2DrawAmount, spoke2RiskPremiumRay); // trigger base debt update

    // debt has been not been accrued for spoke 1 individually yet
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, spoke1DrawAmount);

    totalBaseDebt += spoke1AccruedDebt + spoke2DrawAmount;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    uint256 expectedRiskPremium = ((spoke1DrawAmount + spoke1AccruedDebt) * // correctly account for spoke1 debt
      spoke1RiskPremiumRay +
      spoke2DrawAmount *
      spoke2RiskPremiumRay) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertEq(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium);

    lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(timeToSkip);

    spoke1DrawAmount += spoke1AccruedDebt;
    spoke1AccruedDebt = spoke1DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    );
    uint256 spoke2AccruedDebt = spoke2DrawAmount.rayMul(
      MathUtils.calculateLinearInterest(rate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, spoke3DrawAmount, spoke3RiskPremiumRay);

    totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + spoke3DrawAmount;
    expectedRiskPremium =
      ((spoke1DrawAmount + spoke1AccruedDebt) *
        spoke1RiskPremiumRay +
        (spoke2DrawAmount + spoke2AccruedDebt) *
        spoke2RiskPremiumRay +
        spoke3DrawAmount *
        spoke3RiskPremiumRay) /
      totalBaseDebt;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium, 1);
  }

  function test_fuzzMultipleDrawWhileAccruingInterest(
    TestDrawAmountAndRiskPremiumRayInput memory p,
    uint256 timeToSkip,
    uint256 baseBorrowRate
  ) public {
    // todo: minDrawAmount temp workaround
    p = bound({input: p, minDrawAmount: daiAmount / 1e9, maxDrawAmount: daiAmount});
    timeToSkip = bound(timeToSkip, 1 days, 100_000 days);
    baseBorrowRate = bound(baseBorrowRate, uint256(1).bpsToRay(), uint256(100_00).bpsToRay());
    uint40 lastUpdateTimestamp = uint40(vm.getBlockTimestamp());

    uint256 totalToDraw = p.drawAmount.spoke1 + p.drawAmount.spoke2 + p.drawAmount.spoke3;

    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    vm.prank(address(spoke1));
    hub.supply(daiAssetId, totalToDraw, p.riskPremiumRay.spoke1, alice);

    // spoke 1 draws
    vm.prank(address(spoke1));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke1, p.riskPremiumRay.spoke1);

    uint256 totalBaseDebt = p.drawAmount.spoke1;
    assertEq(hub.getAsset(daiAssetId).baseDebt, p.drawAmount.spoke1);
    assertEq(hub.getAssetRiskPremium(daiAssetId), p.riskPremiumRay.spoke1);

    skip(timeToSkip);
    uint256 spoke1AccruedDebt = p.drawAmount.spoke1.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // borrow baseBorrowRate changes with this action
    baseBorrowRate *= 2;
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate)
    );

    // spoke 2 draws
    vm.prank(address(spoke2));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke2, p.riskPremiumRay.spoke2); // trigger base debt update

    // debt has been not been accrued for spoke 1 individually yet
    assertEq(hub.getSpoke(daiAssetId, address(spoke1)).baseDebt, p.drawAmount.spoke1);

    totalBaseDebt += spoke1AccruedDebt + p.drawAmount.spoke2;
    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt); // totalDebt has been accrued

    uint256 expectedRiskPremium = ((p.drawAmount.spoke1 + spoke1AccruedDebt) * // correctly account for spoke1 debt
      p.riskPremiumRay.spoke1 +
      p.drawAmount.spoke2 *
      p.riskPremiumRay.spoke2) / totalBaseDebt;

    assertEq(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt);
    assertApproxEqAbs(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium, 1);

    lastUpdateTimestamp = uint40(vm.getBlockTimestamp());
    skip(timeToSkip);

    p.drawAmount.spoke1 += spoke1AccruedDebt;
    spoke1AccruedDebt = p.drawAmount.spoke1.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );
    uint256 spoke2AccruedDebt = p.drawAmount.spoke2.rayMul(
      MathUtils.calculateLinearInterest(baseBorrowRate, lastUpdateTimestamp) - WadRayMath.RAY
    );

    // spoke 3 draws remaining liquidity
    vm.prank(address(spoke3));
    hub.draw(daiAssetId, alice, p.drawAmount.spoke3, p.riskPremiumRay.spoke3);

    totalBaseDebt += spoke1AccruedDebt + spoke2AccruedDebt + p.drawAmount.spoke3;
    expectedRiskPremium =
      ((p.drawAmount.spoke1 + spoke1AccruedDebt) *
        p.riskPremiumRay.spoke1 +
        (p.drawAmount.spoke2 + spoke2AccruedDebt) *
        p.riskPremiumRay.spoke2 +
        p.drawAmount.spoke3 *
        p.riskPremiumRay.spoke3) /
      totalBaseDebt;
    assertApproxEqAbs(hub.getAsset(daiAssetId).baseDebt, totalBaseDebt, 2);
    assertApproxEqAbs(hub.getAssetRiskPremium(daiAssetId), expectedRiskPremium, 3);
  }
}
