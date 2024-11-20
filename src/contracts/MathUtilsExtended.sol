// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/**
 * @title WeightedAverageFull
 * @notice Library for calculating weighted averages with full 512-bit precision
 * @dev The library requires storing newWeightedSum in full 512-bit precision (ie two slots)
 * @dev uses Uint512 for currentWeightedSum
 * @dev This library is a proof of concept for calculating weighted averages with full 512-bit precision
 * @dev This can be heavily optimized by not using a struct (U512) but rather keep the two slots in the stack
 * and perform add/sub operations in yul
 */
library WeightedAverageFull {
  /**
   * @dev using a struct for brevity right now, more gas efficient to use two variables
   * in the stack and avoid pushing to memory, solidity does not support complex value types
   */
  struct U512 {
    uint256 x0; // least significant 256 bits
    uint256 x1; // most significant 256 bits
  }

  /**
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights added with a new value, weight
   * @param currentWeightedSum The base weighted sum
   * @param currentSumWeights The base sum of weights
   * @param newValue The new value to add or subtract
   * @param newValueWeight The weight of the new value
   * @return newWeightedSum The weighted sum after operation
   * @return newSumWeights The sum of weights after operation, cannot be less than 0
   * @return weightedAvg The weighted average after the operation
   * @dev Reverts when zero weightedValue (newValue * newValueWeight) is being added to
   * zero currentWeightedSum
   */
  function addToWeightedAverageFull(
    U512 memory currentWeightedSum,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal view returns (U512 memory, uint256, uint256) {
    // newWeightedSum, newSumWeights, weightedAvg
    U512 memory newWeightedValue = mul(newValue, newValueWeight);
    if (currentSumWeights == 0) {
      return (newWeightedValue, newValueWeight, newValue); // newWeightedValue = newWeightedSum for the first value
    }

    uint256 newSumWeights = currentSumWeights + newValueWeight;
    U512 memory newWeightedSum = add(currentWeightedSum, newWeightedValue);

    // newSumWeights can never zero because currentSumWeights is non zero when execution reaches here
    return (newWeightedSum, newSumWeights, div(newWeightedSum, newSumWeights));
  }

  /**
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights subtracted with a new value, weight
   * @param currentWeightedSum The base weighted sum
   * @param currentSumWeights The base sum of weights
   * @param newValue The new value to add or subtract
   * @param newValueWeight The weight of the new value
   * @return newWeightedSum The weighted sum after operation
   * @return newSumWeights The sum of weights after operation, cannot be less than 0
   * @return weightedAvg The weighted average after the operation
   * @dev Reverts when newValueWeight is greater than currentSumWeights
   * @dev Reverts when the newWeightedValue (weight * value) is greater than currentWeightedSum
   */
  function subtractFromWeightedAverageFull(
    U512 memory currentWeightedSum,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal view returns (U512 memory, uint256, uint256) {
    // newWeightedSum, newSumWeights, weightedAvg
    if (currentSumWeights == newValueWeight) return (U512(0, 0), 0, 0);
    if (currentSumWeights < newValueWeight) revert();

    U512 memory newWeightedValue = mul(newValue, newValueWeight);

    if (lt(currentWeightedSum, newWeightedValue)) revert();

    uint256 newSumWeights = currentSumWeights - newValueWeight;
    U512 memory newWeightedSum = sub(currentWeightedSum, newWeightedValue);

    return (newWeightedSum, newSumWeights, div(newWeightedSum, newSumWeights));
  }

  /**
   * @notice Multiplies two uint256's and returns the result in 512-bit
   * @dev credit to & adapted from https://xn--2-umb.com/17/full-mul/
   */
  function mul(uint256 a, uint256 b) internal pure returns (U512 memory) {
    // 512-bit multiply [prod1 prod0] = a * b
    // Compute the product mod 2**256 and mod 2**256 - 1
    // then use the Chinese Remainder Theorem to reconstruct
    // the 512 bit result. The result is stored in two 256
    // variables such that product = prod1 * 2**256 + prod0
    uint256 prod0 = a * b; // Least significant 256 bits of the product
    uint256 prod1; // Most significant 256 bits of the product
    assembly ('memory-safe') {
      let mm := mulmod(a, b, not(0))
      prod1 := sub(sub(mm, prod0), lt(mm, prod0))
    }
    return U512({x0: prod0, x1: prod1});
  }

  /**
   * @notice Adds two 512 bit numbers and returns the result in 512-bit
   * @dev credit to & adapted from https://xn--2-umb.com/17/512-bit-division/
   */
  function add(U512 memory a, U512 memory b) internal pure returns (U512 memory) {
    U512 memory result;
    // overflow is desired
    unchecked {
      result.x0 = a.x0 + b.x0;
      result.x1 = a.x1 + b.x1 + (result.x0 < a.x0 ? 1 : 0); // add 1 is result.x0 overflowed
    }
  }

  /**
   * @notice Subtracts two 512 bit numbers and returns the result in 512-bit
   * @dev credit to & adapted from https://xn--2-umb.com/17/512-bit-division/
   */
  function sub(U512 memory a, U512 memory b) internal pure returns (U512 memory) {
    U512 memory result;
    // overflow is desired
    unchecked {
      result.x0 = a.x0 - b.x0;
      result.x1 = a.x1 - b.x1 - (a.x0 < b.x0 ? 1 : 0); // sub 1 is result.x0 overflowed
    }
  }

  /**
   * @notice Divides a 512 bit number with a 256-bit number and returns the result in lower 256-bit
   * @dev credit to & adapted from https://xn--2-umb.com/17/512-bit-division/
   */
  function div(U512 memory a, uint256 denominator) internal pure returns (uint256) {
    U512 memory tmp;
    U512 memory result;

    uint256 q = div256(denominator);
    uint256 r = mod256(denominator);
    // unoptimized, max 256 iterations
    while (a.x1 != 0) {
      tmp = mul(a.x1, q);
      result = add(result, tmp);
      tmp = mul(a.x1, r);
      a = add(tmp, U512({x0: a.x0, x1: 0}));
    }
    result = add(result, U512({x0: a.x0 / denominator, x1: 0}));
    return result.x0;
  }

  /**
   * @notice Divides 2 ^ 256 by the given number
   */
  function div256(uint256 a) internal pure returns (uint256 r) {
    require(a > 1);
    assembly ('memory-safe') {
      r := add(div(sub(0, a), a), 1)
    }
  }

  /**
   * @notice Computes 2 ^ 256 modulo given number
   */
  function mod256(uint256 a) internal pure returns (uint256 r) {
    require(a != 0);
    assembly ('memory-safe') {
      r := mod(sub(0, a), a)
    }
  }

  /**
   * Performs less-than comparison on two U512 numbers
   */
  function lt(U512 memory a, U512 memory b) internal pure returns (bool) {
    return a.x1 < b.x1 || (a.x1 == b.x1 && a.x0 < b.x0);
  }
}
