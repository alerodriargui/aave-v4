// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

contract MathUtilsTest is BaseTest {
  using WadRayMath for uint256;

  /// forge-config: default.fuzz.runs = 10000
  function testFuzzNewWeightedAverageAdd(uint256[] memory numbers) public {
    vm.assume(numbers.length > 0);

    uint256 currentSumWeights;
    uint256 currentWeightedAvgRad;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;
    uint256 number;
    uint256 weight;

    for (uint256 i; i < numbers.length; ++i) {
      // truncate
      number = numbers[i] % type(uint128).max;
      weight = numbers[i] % 100_00; // bps

      calcWeightedAvg += number * weight;
      calcSumWeights += weight;

      (currentWeightedAvgRad, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        number,
        weight
      );
    }
    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    assertApproxEqAbs(currentWeightedAvgRad.fromRad(), calcWeightedAvg, 1);
    assertEq(currentSumWeights, calcSumWeights);
  }

  /// forge-config: default.fuzz.runs = 10000
  function testFuzzNewWeightedAverageRemove(uint256[] memory numbers, uint256 toRemoveIdx) public {
    vm.assume(numbers.length > 1);
    toRemoveIdx = bound(toRemoveIdx, 0, numbers.length - 1);

    uint256 currentSumWeights;
    uint256 currentWeightedAvgRad;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;
    uint256 number;
    uint256 weight;

    for (uint256 i; i < numbers.length; ++i) {
      // truncate
      number = numbers[i] % type(uint128).max;
      weight = numbers[i] % 100_00; // bps

      if (i != toRemoveIdx) {
        calcWeightedAvg += number * weight;
        calcSumWeights += weight;
      }

      (currentWeightedAvgRad, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        number,
        weight
      );
    }

    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    uint256 newValue = numbers[toRemoveIdx] % type(uint128).max;
    uint256 newValueWeight = numbers[toRemoveIdx] % 100_00;

    if (currentWeightedAvgRad * currentSumWeights < (newValue * newValueWeight).toRad()) {
      vm.expectRevert();
      MathUtils.subtractFromWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        newValue,
        newValueWeight
      );
    } else {
      (currentWeightedAvgRad, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
        currentWeightedAvgRad,
        currentSumWeights,
        newValue,
        newValueWeight
      );

      assertApproxEqAbs(currentWeightedAvgRad.fromRad(), calcWeightedAvg, 1);
      assertEq(currentSumWeights, calcSumWeights);
    }
  }
}
