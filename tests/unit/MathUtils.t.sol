// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../BaseTest.t.sol';

/** notes
 add test
 - adding all, and then removing every other value (test_fuzz_WeightedAverageRemoveMultiple is more comprehensive)
 - only add max possible values at each step, limits for overflow

todo
 - add wad precision

 ceiling values (value, weight): 1e4, 1e45 and 1e18, 1e30 
 from https://www.notion.so/aave/Updated-Incremental-Weighted-Average-Usage-1469d63a22de80d3aebdedae4de6deb2?pvs=4

test_fuzz_WeightedAverageRemoveSingle
in: values: [1000000000000000000000000000 [1e27], 1727], toRemoveIndex: 0
1e27 eats up 1727
 */

contract MathUtilsTest is BaseTest {
  using WadRayMath for uint256;

  struct Set {
    uint256[] keys;
    mapping(uint256 key => bool seen) contains;
  }
  Set internal toRemoveSet;

  /// forge-config: ci.fuzz.runs = 10000
  function test_fuzz_WeightedAverageAdd(uint256[] memory values) public pure {
    _runWeightedAverageAdd(values, 1e4, 1e45);
    _runWeightedAverageAdd(values, 1e18, 1e30);
  }

  /// forge-config: ci.fuzz.runs = 10000
  function test_fuzz_WeightedAverageRemoveMultiple(
    uint256[] memory values,
    uint256[] memory toRemoveIndexes
  ) public {
    _runWeightedAverageRemove(values, toRemoveIndexes, 1e4, 1e45);
    _runWeightedAverageRemove(values, toRemoveIndexes, 1e18, 1e30);
  }

  /// forge-config: ci.fuzz.runs = 10000
  function test_fuzz_WeightedAverageRemoveSingle(
    uint256[] memory values,
    uint256 toRemoveIndex
  ) public {
    uint256[] memory toRemoveIndexes = new uint256[](1);
    toRemoveIndexes[0] = toRemoveIndex;
    _runWeightedAverageRemove(values, toRemoveIndexes, 1e4, 1e45);
    _runWeightedAverageRemove(values, toRemoveIndexes, 1e18, 1e30);
  }

  function test_fuzz_Revert_WeightedAverageRemoveInvalidWeightedValue(
    uint256[] memory values
  ) public {
    _runWeightedAverageRemoveInvalidWeightedValue(values, 1e4, 1e45);
    _runWeightedAverageRemoveInvalidWeightedValue(values, 1e18, 1e30);
  }

  function _runWeightedAverageRemoveInvalidWeightedValue(
    uint256[] memory values,
    uint256 valueCeiling,
    uint256 weightCeiling
  ) internal {
    (uint256 currentWeightedAvg, uint256 currentSumWeights) = _runWeightedAverageAdd(
      values,
      valueCeiling,
      weightCeiling
    );

    for (uint256 i; i < values.length; ++i) {
      uint256 maxValue;
      uint256 maxWeight;
      for (uint256 j = i; j < values.length; ++j) {
        maxValue = _max(maxValue, values[j] % valueCeiling);
        maxWeight = _max(maxWeight, values[j] % weightCeiling);
      }

      vm.expectRevert();
      MathUtils.subtractFromWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        maxValue + 1,
        maxWeight + 1
      );

      uint256 number = values[i] % valueCeiling;
      uint256 weight = values[i] % weightCeiling;

      (currentWeightedAvg, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        number,
        weight
      );
    }
  }

  function _runWeightedAverageAdd(
    uint256[] memory values,
    uint256 valueCeiling,
    uint256 weightCeiling
  ) public pure returns (uint256, uint256) {
    vm.assume(values.length > 0);

    uint256 currentSumWeights;
    uint256 currentWeightedAvg;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;
    uint256 number;
    uint256 weight;

    for (uint256 i; i < values.length; ++i) {
      // truncate
      number = (values[i] % valueCeiling).toRad(); // add precision before
      weight = values[i] % weightCeiling;

      calcWeightedAvg += number * weight;
      calcSumWeights += weight;

      (currentWeightedAvg, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        number,
        weight
      );
    }
    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    assertApproxEqAbs(currentWeightedAvg.fromRad(), calcWeightedAvg.fromRad(), 1);
    assertEq(currentSumWeights, calcSumWeights);

    return (currentWeightedAvg, currentSumWeights);
  }

  function _runWeightedAverageRemove(
    uint256[] memory values,
    uint256[] memory toRemoveIndexes,
    uint256 valueCeiling,
    uint256 weightCeiling
  ) public {
    vm.assume(values.length > 1);

    for (uint256 i; i < _min(values.length, toRemoveIndexes.length); ++i) {
      uint256 key = bound(toRemoveIndexes[i], 0, values.length - 1);
      if (!toRemoveSet.contains[key]) {
        // toRemoveSet is not persisted between runs
        toRemoveSet.keys.push(key);
        toRemoveSet.contains[key] = true;
      }
    }

    uint256 currentSumWeights;
    uint256 currentWeightedAvg;

    uint256 calcWeightedAvg;
    uint256 calcSumWeights;

    for (uint256 i; i < values.length; ++i) {
      // truncate
      uint256 number = (values[i] % valueCeiling).toRad(); // add precision before
      uint256 weight = values[i] % weightCeiling;

      if (!toRemoveSet.contains[i]) {
        calcWeightedAvg += number * weight;
        calcSumWeights += weight;
      }

      (currentWeightedAvg, currentSumWeights) = MathUtils.addToWeightedAverage(
        currentWeightedAvg,
        currentSumWeights,
        number,
        weight
      );
    }

    if (calcSumWeights != 0) {
      calcWeightedAvg /= calcSumWeights;
    }

    for (uint256 i; i < toRemoveSet.keys.length; ++i) {
      uint256 newValue = (values[toRemoveSet.keys[i]] % valueCeiling).toRad(); // add precision before
      uint256 newValueWeight = values[toRemoveSet.keys[i]] % weightCeiling;

      // overflow not possible
      if (currentWeightedAvg * currentSumWeights < (newValue * newValueWeight).toRad()) {
        vm.expectRevert();
        MathUtils.subtractFromWeightedAverage(
          currentWeightedAvg,
          currentSumWeights,
          newValue,
          newValueWeight
        );
      } else {
        (currentWeightedAvg, currentSumWeights) = MathUtils.subtractFromWeightedAverage(
          currentWeightedAvg,
          currentSumWeights,
          newValue,
          newValueWeight
        );
      }
    }

    assertApproxEqAbs(currentWeightedAvg.fromRad(), calcWeightedAvg.fromRad(), 2);
    assertEq(currentSumWeights, calcSumWeights);
  }

  function _min(uint256 a, uint256 b) private pure returns (uint256) {
    return a < b ? a : b;
  }

  function _max(uint256 a, uint256 b) private pure returns (uint256) {
    return a > b ? a : b;
  }
}
