// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {WadRayMath} from './WadRayMath.sol';

/**
 * @title MathUtils library
 * @author Aave
 * @notice Provides functions to perform linear and compounded interest calculations
 */
library MathUtils {
  using WadRayMath for uint256;

  /// @dev Ignoring leap years
  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  /**
   * @dev Function to calculate the interest accumulated using a linear interest rate formula
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate linearly accumulated during the timeDelta, in ray
   */
  function calculateLinearInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    //solium-disable-next-line
    uint256 result = rate * (block.timestamp - uint256(lastUpdateTimestamp));
    unchecked {
      result = result / SECONDS_PER_YEAR;
    }

    return WadRayMath.RAY + result;
  }

  /**
   * @dev Function to calculate the interest using a compounded interest rate formula
   * To avoid expensive exponentiation, the calculation is performed using a binomial approximation:
   *
   *  (1+x)^n = 1+n*x+[n/2*(n-1)]*x^2+[n/6*(n-1)*(n-2)*x^3...
   *
   * The approximation slightly underpays liquidity providers and undercharges borrowers, with the advantage of great
   * gas cost reductions. The whitepaper contains reference to the approximation and a table showing the margin of
   * error per different time periods
   *
   * @param rate The interest rate, in ray
   * @param lastUpdateTimestamp The timestamp of the last update of the interest
   * @return The interest rate compounded during the timeDelta, in ray
   */
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp,
    uint256 currentTimestamp
  ) internal pure returns (uint256) {
    //solium-disable-next-line
    uint256 exp = currentTimestamp - uint256(lastUpdateTimestamp);

    if (exp == 0) {
      return WadRayMath.RAY;
    }

    uint256 expMinusOne;
    uint256 expMinusTwo;
    uint256 basePowerTwo;
    uint256 basePowerThree;
    unchecked {
      expMinusOne = exp - 1;

      expMinusTwo = exp > 2 ? exp - 2 : 0;

      basePowerTwo = rate.rayMul(rate) / (SECONDS_PER_YEAR * SECONDS_PER_YEAR);
      basePowerThree = basePowerTwo.rayMul(rate) / SECONDS_PER_YEAR;
    }

    uint256 secondTerm = exp * expMinusOne * basePowerTwo;
    unchecked {
      secondTerm /= 2;
    }
    uint256 thirdTerm = exp * expMinusOne * expMinusTwo * basePowerThree;
    unchecked {
      thirdTerm /= 6;
    }

    return WadRayMath.RAY + (rate * exp) / SECONDS_PER_YEAR + secondTerm + thirdTerm;
  }

  /**
   * @dev Calculates the compounded interest between the timestamp of the last update and the current block timestamp
   * @param rate The interest rate (in ray)
   * @param lastUpdateTimestamp The timestamp from which the interest accumulation needs to be calculated
   * @return The interest rate compounded between lastUpdateTimestamp and current block timestamp, in ray
   */
  function calculateCompoundedInterest(
    uint256 rate,
    uint40 lastUpdateTimestamp
  ) internal view returns (uint256) {
    return calculateCompoundedInterest(rate, lastUpdateTimestamp, block.timestamp);
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
   * @dev Reverts when zero weightedValue (newValue * newValueWeight) is being added to
   * zero currentWeightedSum
   */
  function addToWeightedAverage(
    uint256 currentWeightedSum,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal view returns (uint256, uint256, uint256) {
    // newWeightedSum, newSumWeights, weightedAvg
    if (currentSumWeights == 0) {
      return (newValue * newValueWeight, newValueWeight, newValue);
    }

    uint256 newSumWeights = currentSumWeights + newValueWeight;
    uint256 newWeightedSum = currentWeightedSum + newValue * newValueWeight;

    // newSumWeights can never zero because currentSumWeights is non zero when execution reaches here
    return (newWeightedSum, newSumWeights, newWeightedSum / newSumWeights);
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
   * @dev Reverts when newValueWeight is greater than currentSumWeights
   * @dev Reverts when the newWeightedValue (weight * value) is greater than currentWeightedSum
   */
  function subtractFromWeightedAverage(
    uint256 currentWeightedSum,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal view returns (uint256, uint256, uint256) {
    // newWeightedSum, newSumWeights, weightedAvg
    if (currentSumWeights == newValueWeight) return (0, 0, 0);
    if (currentSumWeights < newValueWeight) revert();
    if (currentWeightedSum < newValue * newValueWeight) revert();

    uint256 newSumWeights = currentSumWeights - newValueWeight;
    uint256 newWeightedSum = currentWeightedSum - newValue * newValueWeight;

    return (newWeightedSum, newSumWeights, newWeightedSum / newSumWeights);
  }

  function mulAndAdd(
    uint256 a0,
    uint256 a1,
    uint256 b0,
    uint256 b1,
    uint256 denominator
  ) internal pure returns (uint256 r0, uint256 r1, uint256 remainder) {
    (uint256 resA0, uint256 resA1) = mulFull(a0, a1);
    (uint256 resB0, uint256 resB1) = mulFull(b0, b1);

    assembly ('memory-safe') {
      // compute remainders for both multiplications using mulmod
      let remainderA := mulmod(a0, a1, denominator)
      let remainderB := mulmod(b0, b1, denominator)

      remainder := add(remainderA, remainderB)
      // add 1 if remainder overflows 256 bits
      r0 := add(r0, lt(remainderA, remainder))
    }

    // add two 512 bit numbers
    assembly ('memory-safe') {
      r0 := add(r0, add(resA0, resB0))
      r1 := add(add(resA1, resB1), lt(r0, resA0))
    }
  }

  function mulAndSub(
    uint256 a0,
    uint256 a1,
    uint256 b0,
    uint256 b1,
    uint256 denominator
  ) internal pure returns (uint256 r0, uint256 r1, uint256 remainder) {
    (uint256 resA0, uint256 resA1) = mulFull(a0, a1);
    (uint256 resB0, uint256 resB1) = mulFull(b0, b1);

    assembly ('memory-safe') {
      // compute remainders for both multiplications using mulmod
      let remainderA := mulmod(a0, a1, denominator)
      let remainderB := mulmod(b0, b1, denominator)

      remainder := add(remainderA, remainderB)
      // add 1 if remainder overflows 256 bits
      r0 := add(r0, lt(remainderA, remainder))
    }

    // subtract two 512 bit numbers
    assembly ('memory-safe') {
      r0 := sub(resA0, resB0)
      r1 := sub(sub(resA1, resB1), lt(resA0, resB0))
    }
  }

  /**
   * @notice Multiplies two uint256's and returns the result in 512-bit
   * @dev adapted from uniswap v4-core: https://github.com/Uniswap/v4-core/blob/main/src/libraries/FullMath.sol
   * @param a The multiplicand
   * @param b The multiplier
   * @return prod0 Least significant 256 bits of the product
   * @return prod1 Most significant 256 bits of the product
   */
  function mulFull(uint256 a, uint256 b) internal pure returns (uint256, uint256) {
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
    return (prod0, prod1);
  }

  /**
   * @notice Divides 512 bit number ([prod0 prod1]) by denominator, rounding down
   * @dev adapted from uniswap v4-core: https://github.com/Uniswap/v4-core/blob/main/src/libraries/FullMath.sol
   * @param prod0 Least significant 256 bits of the product
   * @param prod1 Most significant 256 bits of the product
   * @param remainder The remainder original multiplicands to make division exact
   * @param denominator The divisor
   * @return result The 256-bit result
   */
  function fullDiv(
    uint256 prod0,
    uint256 prod1,
    uint256 remainder,
    uint256 denominator
  ) internal pure returns (uint256 result) {
    unchecked {
      // Make sure the result is less than 2**256.
      // Also prevents denominator == 0
      require(denominator > prod1);

      // Handle non-overflow cases, 256 by 256 division
      if (prod1 == 0) {
        assembly ('memory-safe') {
          result := div(prod0, denominator)
        }
        return result;
      }

      ///////////////////////////////////////////////
      // 512 by 256 division.
      ///////////////////////////////////////////////

      // Make division exact by subtracting the remainder from [prod1 prod0]
      // Subtract 256 bit number from 512 bit number
      assembly ('memory-safe') {
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
      }

      // Factor powers of two out of denominator
      // Compute largest power of two divisor of denominator.
      // Always >= 1.
      uint256 twos = (0 - denominator) & denominator;
      // Divide denominator by power of two
      assembly ('memory-safe') {
        denominator := div(denominator, twos)
      }

      // Divide [prod1 prod0] by the factors of two
      assembly ('memory-safe') {
        prod0 := div(prod0, twos)
      }
      // Shift in bits from prod1 into prod0. For this we need
      // to flip `twos` such that it is 2**256 / twos.
      // If twos is zero, then it becomes one
      assembly ('memory-safe') {
        twos := add(div(sub(0, twos), twos), 1)
      }
      prod0 |= prod1 * twos;

      // Invert denominator mod 2**256
      // Now that denominator is an odd number, it has an inverse
      // modulo 2**256 such that denominator * inv = 1 mod 2**256.
      // Compute the inverse by starting with a seed that is correct
      // correct for four bits. That is, denominator * inv = 1 mod 2**4
      uint256 inv = (3 * denominator) ^ 2;
      // Now use Newton-Raphson iteration to improve the precision.
      // Thanks to Hensel's lifting lemma, this also works in modular
      // arithmetic, doubling the correct bits in each step.
      inv *= 2 - denominator * inv; // inverse mod 2**8
      inv *= 2 - denominator * inv; // inverse mod 2**16
      inv *= 2 - denominator * inv; // inverse mod 2**32
      inv *= 2 - denominator * inv; // inverse mod 2**64
      inv *= 2 - denominator * inv; // inverse mod 2**128
      inv *= 2 - denominator * inv; // inverse mod 2**256

      // Because the division is now exact we can divide by multiplying
      // with the modular inverse of denominator. This will give us the
      // correct result modulo 2**256. Since the preconditions guarantee
      // that the outcome is less than 2**256, this is the final result.
      // We don't need to compute the high bits of the result and prod1
      // is no longer required.
      result = prod0 * inv;
      return result;
    }
  }

  /**
   * @notice Calculates floor(a×b÷denominator) with full precision rounded down. Throws if result overflows a uint256 or denominator == 0
   * @dev adapted from uniswap v4-core: https://github.com/Uniswap/v4-core/blob/main/src/libraries/FullMath.sol
   * @dev Handles "phantom overflow" i.e., allows multiplication and division where an intermediate value overflows 256 bits
   * @param a The multiplicand
   * @param b The multiplier
   * @param denominator The divisor
   * @return result The 256-bit result
   * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
   */
  function mulDiv(
    uint256 a,
    uint256 b,
    uint256 denominator
  ) internal pure returns (uint256 result) {
    unchecked {
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

      // Make sure the result is less than 2**256.
      // Also prevents denominator == 0
      require(denominator > prod1);

      // Handle non-overflow cases, 256 by 256 division
      if (prod1 == 0) {
        assembly ('memory-safe') {
          result := div(prod0, denominator)
        }
        return result;
      }

      ///////////////////////////////////////////////
      // 512 by 256 division.
      ///////////////////////////////////////////////

      // Make division exact by subtracting the remainder from [prod1 prod0]
      // Compute remainder using mulmod
      uint256 remainder;
      assembly ('memory-safe') {
        remainder := mulmod(a, b, denominator)
      }
      // Subtract 256 bit number from 512 bit number
      assembly ('memory-safe') {
        prod1 := sub(prod1, gt(remainder, prod0))
        prod0 := sub(prod0, remainder)
      }

      // Factor powers of two out of denominator
      // Compute largest power of two divisor of denominator.
      // Always >= 1.
      uint256 twos = (0 - denominator) & denominator;
      // Divide denominator by power of two
      assembly ('memory-safe') {
        denominator := div(denominator, twos)
      }

      // Divide [prod1 prod0] by the factors of two
      assembly ('memory-safe') {
        prod0 := div(prod0, twos)
      }
      // Shift in bits from prod1 into prod0. For this we need
      // to flip `twos` such that it is 2**256 / twos.
      // If twos is zero, then it becomes one
      assembly ('memory-safe') {
        twos := add(div(sub(0, twos), twos), 1)
      }
      prod0 |= prod1 * twos;

      // Invert denominator mod 2**256
      // Now that denominator is an odd number, it has an inverse
      // modulo 2**256 such that denominator * inv = 1 mod 2**256.
      // Compute the inverse by starting with a seed that is correct
      // correct for four bits. That is, denominator * inv = 1 mod 2**4
      uint256 inv = (3 * denominator) ^ 2;
      // Now use Newton-Raphson iteration to improve the precision.
      // Thanks to Hensel's lifting lemma, this also works in modular
      // arithmetic, doubling the correct bits in each step.
      inv *= 2 - denominator * inv; // inverse mod 2**8
      inv *= 2 - denominator * inv; // inverse mod 2**16
      inv *= 2 - denominator * inv; // inverse mod 2**32
      inv *= 2 - denominator * inv; // inverse mod 2**64
      inv *= 2 - denominator * inv; // inverse mod 2**128
      inv *= 2 - denominator * inv; // inverse mod 2**256

      // Because the division is now exact we can divide by multiplying
      // with the modular inverse of denominator. This will give us the
      // correct result modulo 2**256. Since the preconditions guarantee
      // that the outcome is less than 2**256, this is the final result.
      // We don't need to compute the high bits of the result and prod1
      // is no longer required.
      result = prod0 * inv;
      return result;
    }
  }
}
