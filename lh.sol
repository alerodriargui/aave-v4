// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0 ^0.8.10 ^0.8.20;

// src/contracts/PercentageMath.sol

/**
 * @title PercentageMath library
 * @author Aave
 * @notice Provides functions to perform percentage calculations
 * @dev Percentages are defined by default with 2 decimals of precision (100.00). The precision is indicated by PERCENTAGE_FACTOR
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library PercentageMath {
  // Maximum percentage factor (100.00%)
  uint256 internal constant PERCENTAGE_FACTOR = 1e4;

  // Half percentage factor (50.00%)
  uint256 internal constant HALF_PERCENTAGE_FACTOR = 0.5e4;

  /**
   * @notice Executes a percentage multiplication
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentmul percentage
   */
  function percentMul(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - HALF_PERCENTAGE_FACTOR) / percentage
    assembly {
      if iszero(
        or(
          iszero(percentage),
          iszero(gt(value, div(sub(not(0), HALF_PERCENTAGE_FACTOR), percentage)))
        )
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, percentage), HALF_PERCENTAGE_FACTOR), PERCENTAGE_FACTOR)
    }
  }

  /**
   * @notice Executes a percentage division
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param value The value of which the percentage needs to be calculated
   * @param percentage The percentage of the value to be calculated
   * @return result value percentdiv percentage
   */
  function percentDiv(uint256 value, uint256 percentage) internal pure returns (uint256 result) {
    // to avoid overflow, value <= (type(uint256).max - halfPercentage) / PERCENTAGE_FACTOR
    assembly {
      if or(
        iszero(percentage),
        iszero(iszero(gt(value, div(sub(not(0), div(percentage, 2)), PERCENTAGE_FACTOR))))
      ) {
        revert(0, 0)
      }

      result := div(add(mul(value, PERCENTAGE_FACTOR), div(percentage, 2)), percentage)
    }
  }
}

// src/contracts/WadRayMath.sol

/**
 * @title WadRayMath library
 * @author Aave
 * @notice Provides functions to perform calculations with Wad and Ray units
 * @dev Provides mul and div function for wads (decimal numbers with 18 digits of precision) and rays (decimal numbers
 * with 27 digits of precision)
 * @dev Operations are rounded. If a value is >=.5, will be rounded up, otherwise rounded down.
 */
library WadRayMath {
  // HALF_WAD and HALF_RAY expressed with extended notation as constant with operations are not supported in Yul assembly
  // todo: fix naming for 8 decimal fixed math, RAD is 45
  uint256 internal constant RAD = 1e8;
  uint256 internal constant HALF_RAD = 0.5e8;

  uint256 internal constant WAD = 1e18;
  uint256 internal constant HALF_WAD = 0.5e18;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant HALF_RAY = 0.5e27;

  uint256 internal constant WAD_RAY_RATIO = 1e9;
  uint256 internal constant RAD_RAY_RATIO = 1e19;

  /**
   * @dev Multiplies two wad, rounding half up to the nearest wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @param b Wad
   * @return c = a*b, in wad
   */
  function wadMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - HALF_WAD) / b
    assembly {
      if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_WAD), b))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, b), HALF_WAD), WAD)
    }
  }

  /**
   * @dev Divides two wad, rounding half up to the nearest wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @param b Wad
   * @return c = a/b, in wad
   */
  function wadDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - halfB) / WAD
    assembly {
      if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), WAD))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, WAD), div(b, 2)), b)
    }
  }

  /**
   * @notice Multiplies two ray, rounding half up to the nearest ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @param b Ray
   * @return c = a raymul b
   */
  function rayMul(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - HALF_RAY) / b
    assembly {
      if iszero(or(iszero(b), iszero(gt(a, div(sub(not(0), HALF_RAY), b))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, b), HALF_RAY), RAY)
    }
  }

  /**
   * @notice Divides two ray, rounding half up to the nearest ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @param b Ray
   * @return c = a raydiv b
   */
  function rayDiv(uint256 a, uint256 b) internal pure returns (uint256 c) {
    // to avoid overflow, a <= (type(uint256).max - halfB) / RAY
    assembly {
      if or(iszero(b), iszero(iszero(gt(a, div(sub(not(0), div(b, 2)), RAY))))) {
        revert(0, 0)
      }

      c := div(add(mul(a, RAY), div(b, 2)), b)
    }
  }

  /**
   * @dev Casts ray down to wad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @return b = a converted to wad, rounded half up to the nearest wad
   */
  function rayToWad(uint256 a) internal pure returns (uint256 b) {
    assembly {
      b := div(a, WAD_RAY_RATIO)
      let remainder := mod(a, WAD_RAY_RATIO)
      if iszero(lt(remainder, div(WAD_RAY_RATIO, 2))) {
        b := add(b, 1)
      }
    }
  }

  /**
   * @dev Converts wad up to ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Wad
   * @return b = a converted in ray
   */
  function wadToRay(uint256 a) internal pure returns (uint256 b) {
    // to avoid overflow, b/WAD_RAY_RATIO == a
    assembly {
      b := mul(a, WAD_RAY_RATIO)

      if iszero(eq(div(b, WAD_RAY_RATIO), a)) {
        revert(0, 0)
      }
    }
  }

  /**
   * @dev Casts ray down to rad
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Ray
   * @return b = a converted to rad, rounded half up to the nearest rad
   */
  function rayToRad(uint256 a) internal pure returns (uint256 b) {
    assembly {
      b := div(a, RAD_RAY_RATIO)
      let remainder := mod(a, RAD_RAY_RATIO)
      if iszero(lt(remainder, div(RAD_RAY_RATIO, 2))) {
        b := add(b, 1)
      }
    }
  }

  /**
   * @dev Converts rad up to ray
   * @dev assembly optimized for improved gas savings, see https://twitter.com/transmissions11/status/1451131036377571328
   * @param a Rad
   * @return b = a converted in ray
   */
  function radToRay(uint256 a) internal pure returns (uint256 b) {
    // to avoid overflow, b/RAD_RAY_RATIO == a
    assembly {
      b := mul(a, RAD_RAY_RATIO)

      if iszero(eq(div(b, RAD_RAY_RATIO), a)) {
        revert(0, 0)
      }
    }
  }

  /**
   * @dev Converts number to Rad (8-decimal fixed point units)
   * @param a The number to convert
   * @return b in Ray (b = a * 1e8)
   */
  function toRad(uint256 a) internal pure returns (uint256 b) {
    // to avoid overflow, b/RAD == a
    assembly {
      b := mul(a, RAD)

      if iszero(eq(div(b, RAD), a)) {
        revert(0, 0)
      }
    }
  }

  /**
   * @dev Truncates number from Rad, loosing denominator precision
   * @param a The number in Rad
   * @return b (= a / 1e8, rounded up if remainder is >= 0.5 RAD)
   */
  function fromRad(uint256 a) internal pure returns (uint256 b) {
    assembly {
      b := div(a, RAD)
      let remainder := mod(a, RAD)
      if iszero(lt(remainder, div(RAD, 2))) {
        b := add(b, 1)
      }
    }
  }

  function bpsToRad(uint256 a) internal pure returns (uint256) {
    if (a > 100_00) a = 100_00;
    return (a * RAD) / 100_00;
  }

  function radToBps(uint256 a) internal pure returns (uint256) {
    return (a * 100_00) / RAD;
  }

  function bpsToRay(uint256 a) internal pure returns (uint256) {
    if (a > 100_00) a = 100_00;
    return (a * RAY) / 100_00;
  }

  function rayToBps(uint256 a) internal pure returns (uint256) {
    return (a * 100_00) / RAY;
  }
}

// src/dependencies/openzeppelin/Address.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/Address.sol)

/**
 * @dev Collection of functions related to the address type
 */
library Address {
  /**
   * @dev The ETH balance of the account is not enough to perform the operation.
   */
  error AddressInsufficientBalance(address account);

  /**
   * @dev There's no code at `target` (it is not a contract).
   */
  error AddressEmptyCode(address target);

  /**
   * @dev A call to an address target failed. The target may have reverted.
   */
  error FailedInnerCall();

  /**
   * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
   * `recipient`, forwarding all available gas and reverting on errors.
   *
   * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
   * of certain opcodes, possibly making contracts go over the 2300 gas limit
   * imposed by `transfer`, making them unable to receive funds via
   * `transfer`. {sendValue} removes this limitation.
   *
   * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
   *
   * IMPORTANT: because control is transferred to `recipient`, care must be
   * taken to not create reentrancy vulnerabilities. Consider using
   * {ReentrancyGuard} or the
   * https://solidity.readthedocs.io/en/v0.8.20/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
   */
  function sendValue(address payable recipient, uint256 amount) internal {
    if (address(this).balance < amount) {
      revert AddressInsufficientBalance(address(this));
    }

    (bool success, ) = recipient.call{value: amount}('');
    if (!success) {
      revert FailedInnerCall();
    }
  }

  /**
   * @dev Performs a Solidity function call using a low level `call`. A
   * plain `call` is an unsafe replacement for a function call: use this
   * function instead.
   *
   * If `target` reverts with a revert reason or custom error, it is bubbled
   * up by this function (like regular Solidity function calls). However, if
   * the call reverted with no returned reason, this function reverts with a
   * {FailedInnerCall} error.
   *
   * Returns the raw returned data. To convert to the expected return value,
   * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
   *
   * Requirements:
   *
   * - `target` must be a contract.
   * - calling `target` with `data` must not revert.
   */
  function functionCall(address target, bytes memory data) internal returns (bytes memory) {
    return functionCallWithValue(target, data, 0);
  }

  /**
   * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
   * but also transferring `value` wei to `target`.
   *
   * Requirements:
   *
   * - the calling contract must have an ETH balance of at least `value`.
   * - the called Solidity function must be `payable`.
   */
  function functionCallWithValue(
    address target,
    bytes memory data,
    uint256 value
  ) internal returns (bytes memory) {
    if (address(this).balance < value) {
      revert AddressInsufficientBalance(address(this));
    }
    (bool success, bytes memory returndata) = target.call{value: value}(data);
    return verifyCallResultFromTarget(target, success, returndata);
  }

  /**
   * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
   * but performing a static call.
   */
  function functionStaticCall(
    address target,
    bytes memory data
  ) internal view returns (bytes memory) {
    (bool success, bytes memory returndata) = target.staticcall(data);
    return verifyCallResultFromTarget(target, success, returndata);
  }

  /**
   * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
   * but performing a delegate call.
   */
  function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.delegatecall(data);
    return verifyCallResultFromTarget(target, success, returndata);
  }

  /**
   * @dev Tool to verify that a low level call to smart-contract was successful, and reverts if the target
   * was not a contract or bubbling up the revert reason (falling back to {FailedInnerCall}) in case of an
   * unsuccessful call.
   */
  function verifyCallResultFromTarget(
    address target,
    bool success,
    bytes memory returndata
  ) internal view returns (bytes memory) {
    if (!success) {
      _revert(returndata);
    } else {
      // only check if target is a contract if the call was successful and the return data is empty
      // otherwise we already know that it was a contract
      if (returndata.length == 0 && target.code.length == 0) {
        revert AddressEmptyCode(target);
      }
      return returndata;
    }
  }

  /**
   * @dev Tool to verify that a low level call was successful, and reverts if it wasn't, either by bubbling the
   * revert reason or with a default {FailedInnerCall} error.
   */
  function verifyCallResult(
    bool success,
    bytes memory returndata
  ) internal pure returns (bytes memory) {
    if (!success) {
      _revert(returndata);
    } else {
      return returndata;
    }
  }

  /**
   * @dev Reverts with returndata if present. Otherwise reverts with {FailedInnerCall}.
   */
  function _revert(bytes memory returndata) private pure {
    // Look for revert reason and bubble it up if present
    if (returndata.length > 0) {
      // The easiest way to bubble the revert reason is using memory via assembly
      /// @solidity memory-safe-assembly
      assembly {
        let returndata_size := mload(returndata)
        revert(add(32, returndata), returndata_size)
      }
    } else {
      revert FailedInnerCall();
    }
  }
}

// src/dependencies/openzeppelin/IERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev Emitted when the allowance of a `spender` for an `owner` is set by
   * a call to {approve}. `value` is the new allowance.
   */
  event Approval(address indexed owner, address indexed spender, uint256 value);

  /**
   * @dev Returns the value of tokens in existence.
   */
  function totalSupply() external view returns (uint256);

  /**
   * @dev Returns the value of tokens owned by `account`.
   */
  function balanceOf(address account) external view returns (uint256);

  /**
   * @dev Moves a `value` amount of tokens from the caller's account to `to`.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transfer(address to, uint256 value) external returns (bool);

  /**
   * @dev Returns the remaining number of tokens that `spender` will be
   * allowed to spend on behalf of `owner` through {transferFrom}. This is
   * zero by default.
   *
   * This value changes when {approve} or {transferFrom} are called.
   */
  function allowance(address owner, address spender) external view returns (uint256);

  /**
   * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
   * caller's tokens.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * IMPORTANT: Beware that changing an allowance with this method brings the risk
   * that someone may use both the old and the new allowance by unfortunate
   * transaction ordering. One possible solution to mitigate this race
   * condition is to first reduce the spender's allowance to 0 and set the
   * desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   *
   * Emits an {Approval} event.
   */
  function approve(address spender, uint256 value) external returns (bool);

  /**
   * @dev Moves a `value` amount of tokens from `from` to `to` using the
   * allowance mechanism. `value` is then deducted from the caller's
   * allowance.
   *
   * Returns a boolean value indicating whether the operation succeeded.
   *
   * Emits a {Transfer} event.
   */
  function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// src/dependencies/openzeppelin/IERC20Permit.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/extensions/IERC20Permit.sol)

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 *
 * ==== Security Considerations
 *
 * There are two important considerations concerning the use of `permit`. The first is that a valid permit signature
 * expresses an allowance, and it should not be assumed to convey additional meaning. In particular, it should not be
 * considered as an intention to spend the allowance in any specific way. The second is that because permits have
 * built-in replay protection and can be submitted by anyone, they can be frontrun. A protocol that uses permits should
 * take this into consideration and allow a `permit` call to fail. Combining these two aspects, a pattern that may be
 * generally recommended is:
 *
 * ```solidity
 * function doThingWithPermit(..., uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
 *     try token.permit(msg.sender, address(this), value, deadline, v, r, s) {} catch {}
 *     doThing(..., value);
 * }
 *
 * function doThing(..., uint256 value) public {
 *     token.safeTransferFrom(msg.sender, address(this), value);
 *     ...
 * }
 * ```
 *
 * Observe that: 1) `msg.sender` is used as the owner, leaving no ambiguity as to the signer intent, and 2) the use of
 * `try/catch` allows the permit to fail and makes the code tolerant to frontrunning. (See also
 * {SafeERC20-safeTransferFrom}).
 *
 * Additionally, note that smart contract wallets (such as Argent or Safe) are not able to produce permit signatures, so
 * contracts should have entry points that don't rely on permit.
 */
interface IERC20Permit {
  /**
   * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
   * given ``owner``'s signed approval.
   *
   * IMPORTANT: The same issues {IERC20-approve} has related to transaction
   * ordering also apply here.
   *
   * Emits an {Approval} event.
   *
   * Requirements:
   *
   * - `spender` cannot be the zero address.
   * - `deadline` must be a timestamp in the future.
   * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
   * over the EIP712-formatted function arguments.
   * - the signature must use ``owner``'s current nonce (see {nonces}).
   *
   * For more information on the signature format, see the
   * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
   * section].
   *
   * CAUTION: See Security Considerations above.
   */
  function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  /**
   * @dev Returns the current nonce for `owner`. This value must be
   * included whenever a signature is generated for {permit}.
   *
   * Every successful call to {permit} increases ``owner``'s nonce by one. This
   * prevents a signature from being used multiple times.
   */
  function nonces(address owner) external view returns (uint256);

  /**
   * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
   */
  // solhint-disable-next-line func-name-mixedcase
  function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// src/dependencies/openzeppelin/Math.sol

// OpenZeppelin Contracts (last updated v5.0.0) (utils/math/Math.sol)

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Muldiv operation overflow.
     */
    error MathOverflowedMulDiv();

    enum Rounding {
        Floor, // Toward negative infinity
        Ceil, // Toward positive infinity
        Trunc, // Toward zero
        Expand // Away from zero
    }

    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds towards infinity instead
     * of rounding towards zero.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        if (b == 0) {
            // Guarantee the same behavior as in a regular Solidity division.
            return a / b;
        }

        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or
     * denominator == 0.
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv) with further edits by
     * Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0 = x * y; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            if (denominator <= prod1) {
                revert MathOverflowedMulDiv();
            }

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator.
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.

            uint256 twos = denominator & (0 - denominator);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (unsignedRoundsUp(rounding) && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded
     * towards zero.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (unsignedRoundsUp(rounding) && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (unsignedRoundsUp(rounding) && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (unsignedRoundsUp(rounding) && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256 of a positive value rounded towards zero.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (unsignedRoundsUp(rounding) && 1 << (result << 3) < value ? 1 : 0);
        }
    }

    /**
     * @dev Returns whether a provided rounding mode is considered rounding up for unsigned integers.
     */
    function unsignedRoundsUp(Rounding rounding) internal pure returns (bool) {
        return uint8(rounding) % 2 == 1;
    }
}

// src/libraries/types/DataTypes.sol

library DataTypes {
  struct CalculateInterestRatesParams {
    uint256 liquidityAdded;
    uint256 liquidityTaken;
    uint256 totalDebt;
    uint256 reserveFactor; // likely not required
    uint256 assetId;
    uint256 virtualUnderlyingBalance;
    bool usingVirtualBalance;
  }

  // TODO: borrow cap per spoke
  struct SpokeConfig {
    uint256 drawCap; // asset denominated
    uint256 supplyCap; // asset denominated
  }

  struct AssetConfig {
    uint256 decimals;
    bool active; // TODO: frozen, paused
    address irStrategy;
  }
}

// src/contracts/MathUtils.sol

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
   * @dev Add precision to weighted average & new value before calling this method
   * @param currentWeightedAvg The base weighted average
   * @param currentSumWeights The base sum of weights
   * @param newValue The new value to add or subtract
   * @param newValueWeight The weight of the new value
   * @return newWeightedAvg The weighted average after the operation
   * @return newSumWeights The sum of weights after operation, cannot be less than 0
   */
  function addToWeightedAverage(
    uint256 currentWeightedAvg,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal pure returns (uint256, uint256) {
    // newWeightedAvg, newSumWeights

    if (newValueWeight == 0) {
      return (currentWeightedAvg, currentSumWeights);
    }
    if (currentSumWeights == 0) {
      return (newValue, newValueWeight);
    }

    uint256 newSumWeights = currentSumWeights + newValueWeight;
    uint256 newWeightedAvg = ((currentWeightedAvg * currentSumWeights) +
      (newValue * newValueWeight)) / newSumWeights; // newSumWeights cannot be zero when execution reaches here

    return (newWeightedAvg, newSumWeights);
  }

  /**
   * @notice Calculates the new weighted average given a current weighted average, the sum of the weights added with a new value, weight
   * @dev Add precision to weighted average & new value before calling this method
   * @param currentWeightedAvg The base weighted average
   * @param currentSumWeights The base sum of weights
   * @param newValue The new value to add or subtract
   * @param newValueWeight The weight of the new value
   * @return newWeightedAvg The weighted average after the operation
   * @return newSumWeights The sum of weights after operation, cannot be less than 0
   * @dev Reverts when newValueWeight is greater than currentSumWeights
   * @dev Reverts when the newWeightedValue (weight * value) is greater than currentWeightedSum (currentSumWeights * currentWeightedAvg)
   */
  function subtractFromWeightedAverage(
    uint256 currentWeightedAvg,
    uint256 currentSumWeights,
    uint256 newValue,
    uint256 newValueWeight
  ) internal pure returns (uint256, uint256) {
    // newWeightedAvg, newSumWeights
    if (newValueWeight == 0) return (currentWeightedAvg, currentSumWeights);

    if (currentSumWeights == newValueWeight) return (0, 0); // no change
    if (currentSumWeights < newValueWeight) revert();

    uint256 newWeightedValue = newValue * newValueWeight;
    uint256 currentWeightedSum = currentWeightedAvg * currentSumWeights;

    if (currentWeightedSum < newWeightedValue) revert();

    uint256 newSumWeights = currentSumWeights - newValueWeight;
    uint256 newWeightedAvg = (currentWeightedSum - newWeightedValue) / newSumWeights;

    return (newWeightedAvg, newSumWeights);
  }
}

// src/contracts/SharesMath.sol

library SharesMath {
  using Math for uint256;

  function toSharesDown(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return assets;
    return assets.mulDiv(totalShares, totalAssets, Math.Rounding.Floor);
  }

  function toAssetsDown(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return shares;
    return shares.mulDiv(totalAssets, totalShares, Math.Rounding.Floor);
  }

  function toSharesUp(
    uint256 assets,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return assets;
    return assets.mulDiv(totalShares, totalAssets, Math.Rounding.Ceil);
  }

  function toAssetsUp(
    uint256 shares,
    uint256 totalAssets,
    uint256 totalShares
  ) internal pure returns (uint256) {
    if (totalShares == 0) return shares;
    return shares.mulDiv(totalAssets, totalShares, Math.Rounding.Ceil);
  }
}

// src/interfaces/ILiquidityHub.sol

/**
 * @title ILiquidityHub
 * @author Aave Labs
 * @notice Basic interface for LiquidityHub
 */
interface ILiquidityHub {
  function draw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256);
  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium,
    address repayer
  ) external returns (uint256);
  function supply(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium,
    address supplier
  ) external returns (uint256, uint256);
  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremium
  ) external returns (uint256);

  function getBaseInterestRate(uint256 assetId) external view returns (uint256);

  function addAsset(DataTypes.AssetConfig memory params, address asset) external;
  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external;

  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256);
  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256);
  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256);

  event Supply(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event Withdraw(
    uint256 indexed assetId,
    address indexed spoke,
    address indexed to,
    uint256 amount
  );
  event Draw(uint256 indexed assetId, address indexed spoke, address indexed to, uint256 amount);
  event Restore(uint256 indexed assetId, address indexed spoke, uint256 amount);
  event SpokeAdded(uint256 indexed assetId, address indexed spoke);
}

// src/interfaces/IReserveInterestRateStrategy.sol

/**
 * @title IReserveInterestRateStrategy
 * @author Aave Labs
 * @notice Basic interface for any rate strategy used by the Aave protocol
 */
interface IReserveInterestRateStrategy {
  /**
   * @notice Calculates the interest rates depending on the reserve's state and configurations
   * @param params The parameters needed to calculate interest rates
   * @return variableBorrowRate The variable borrow rate expressed in ray
   */
  function calculateInterestRates(
    DataTypes.CalculateInterestRatesParams memory params
  ) external view returns (uint256);
}

// src/dependencies/openzeppelin/SafeERC20.sol

// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC20/utils/SafeERC20.sol)

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
  using Address for address;

  /**
   * @dev An operation with an ERC20 token failed.
   */
  error SafeERC20FailedOperation(address token);

  /**
   * @dev Indicates a failed `decreaseAllowance` request.
   */
  error SafeERC20FailedDecreaseAllowance(
    address spender,
    uint256 currentAllowance,
    uint256 requestedDecrease
  );

  /**
   * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
   * non-reverting calls are assumed to be successful.
   */
  function safeTransfer(IERC20 token, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
  }

  /**
   * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
   * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
   */
  function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
    _callOptionalReturn(token, abi.encodeCall(token.transferFrom, (from, to, value)));
  }

  /**
   * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
   * non-reverting calls are assumed to be successful.
   */
  function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
    uint256 oldAllowance = token.allowance(address(this), spender);
    forceApprove(token, spender, oldAllowance + value);
  }

  /**
   * @dev Decrease the calling contract's allowance toward `spender` by `requestedDecrease`. If `token` returns no
   * value, non-reverting calls are assumed to be successful.
   */
  function safeDecreaseAllowance(
    IERC20 token,
    address spender,
    uint256 requestedDecrease
  ) internal {
    unchecked {
      uint256 currentAllowance = token.allowance(address(this), spender);
      if (currentAllowance < requestedDecrease) {
        revert SafeERC20FailedDecreaseAllowance(spender, currentAllowance, requestedDecrease);
      }
      forceApprove(token, spender, currentAllowance - requestedDecrease);
    }
  }

  /**
   * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
   * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
   * to be set to zero before setting it to a non-zero value, such as USDT.
   */
  function forceApprove(IERC20 token, address spender, uint256 value) internal {
    bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

    if (!_callOptionalReturnBool(token, approvalCall)) {
      _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
      _callOptionalReturn(token, approvalCall);
    }
  }

  /**
   * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
   * on the return value: the return value is optional (but if data is returned, it must not be false).
   * @param token The token targeted by the call.
   * @param data The call data (encoded using abi.encode or one of its variants).
   */
  function _callOptionalReturn(IERC20 token, bytes memory data) private {
    // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
    // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
    // the target address contains contract code and also asserts for success in the low-level call.

    bytes memory returndata = address(token).functionCall(data);
    if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
      revert SafeERC20FailedOperation(address(token));
    }
  }

  /**
   * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
   * on the return value: the return value is optional (but if data is returned, it must not be false).
   * @param token The token targeted by the call.
   * @param data The call data (encoded using abi.encode or one of its variants).
   *
   * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
   */
  function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
    // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
    // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
    // and not revert is the subcall reverts.

    (bool success, bytes memory returndata) = address(token).call(data);
    return
      success &&
      (returndata.length == 0 || abi.decode(returndata, (bool))) &&
      address(token).code.length > 0;
  }
}

// src/contracts/AssetLogic.sol

library AssetLogic {
  using AssetLogic for Asset;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // todo add remaining: accrue interest, previewNextBorrowIndex, validate*

  // todo: option for cached object

  function totalAssets(Asset storage asset) internal view returns (uint256) {
    return asset.availableLiquidity + asset.outstandingPremium + asset.baseDebt;
  }

  function totalShares(Asset storage asset) internal view returns (uint256) {
    return asset.suppliedShares;
  }

  // @dev So solc doesn't inline
  function getTotalAssets(Asset storage asset) external view returns (uint256) {
    return asset.totalAssets();
  }

  function convertToSharesUp(Asset storage asset, uint256 assets) external view returns (uint256) {
    return assets.toSharesUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToSharesDown(
    Asset storage asset,
    uint256 assets
  ) external view returns (uint256) {
    return assets.toSharesDown(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsUp(Asset storage asset, uint256 shares) external view returns (uint256) {
    return shares.toAssetsUp(asset.totalAssets(), asset.totalShares());
  }

  function convertToAssetsDown(
    Asset storage asset,
    uint256 shares
  ) external view returns (uint256) {
    return shares.toAssetsDown(asset.totalAssets(), asset.totalShares());
  }

  // todo carry out mul in rad for precision
  function getInterestRate(Asset storage asset) external view returns (uint256) {
    return
      asset.baseBorrowRate.percentMul(
        PercentageMath.PERCENTAGE_FACTOR + asset.riskPremiumRad.radToBps()
      );
  }

  function updateBorrowRate(
    Asset storage asset,
    uint256 liquidityAdded,
    uint256 liquidityTaken
  ) internal {
    uint256 baseBorrowRate = IReserveInterestRateStrategy(asset.config.irStrategy)
      .calculateInterestRates(
        DataTypes.CalculateInterestRatesParams({
          liquidityAdded: liquidityAdded,
          liquidityTaken: liquidityTaken,
          totalDebt: asset.baseDebt,
          reserveFactor: 0, // TODO
          assetId: asset.id,
          virtualUnderlyingBalance: asset.availableLiquidity, // without current liquidity change
          usingVirtualBalance: true
        })
      );
    asset.baseBorrowRate = baseBorrowRate;
  }

  // @dev Utilizes existing `asset.baseBorrowRate` & `asset.baseBorrowIndex`
  // @return cumulatedBaseInterest (in ray)
  // @return nextBaseBorrowIndex (in ray)
  function previewNextBorrowIndex(Asset storage asset) internal view returns (uint256, uint256) {
    uint256 elapsed = block.timestamp - asset.lastUpdateTimestamp;
    if (elapsed == 0) return (0, asset.baseBorrowIndex);

    uint256 cumulatedBaseInterest = MathUtils.calculateLinearInterest(
      asset.baseBorrowRate,
      uint40(asset.lastUpdateTimestamp)
    );
    return (cumulatedBaseInterest, cumulatedBaseInterest.rayMul(asset.baseBorrowIndex));
  }

  // @dev Utilizes existing `asset.baseBorrowIndex` & `asset.riskPremiumRad`
  function accrueInterest(
    Asset storage asset,
    uint256 cumulatedBaseInterest,
    uint256 nextBaseBorrowIndex
  ) internal {
    if (cumulatedBaseInterest == 0) return; // no interest accrued since last update

    uint256 existingBaseDebt = asset.baseDebt;
    // no interest to accrue since no liquidity has been drawn
    if (existingBaseDebt == 0) return;

    // can use `cumulatedBaseInterest` instead of `indexRatio` since LH base debt is
    // accrued on each index update
    uint256 cumulatedBaseDebt = asset.baseDebt.rayMul(cumulatedBaseInterest);

    // accrue premium interest on the accrued base interest
    asset.outstandingPremium += (cumulatedBaseDebt - existingBaseDebt).percentMul(
      asset.riskPremiumRad.radToBps()
    );
    asset.baseDebt = cumulatedBaseDebt;
    asset.baseBorrowIndex = nextBaseBorrowIndex;
    asset.lastUpdateTimestamp = block.timestamp;
  }
}

// src/contracts/SpokeDataLogic.sol

library SpokeDataLogic {
  using SpokeDataLogic for SpokeData;
  using PercentageMath for uint256;
  using SharesMath for uint256;
  using WadRayMath for uint256;

  // @dev Utilizes existing `spoke.baseBorrowIndex` & `spoke.riskPremiumRad`
  function accrueInterest(SpokeData storage spoke, uint256 nextBaseBorrowIndex) internal {
    uint256 elapsed = block.timestamp - spoke.lastUpdateTimestamp;
    if (elapsed == 0) return;
    uint256 existingBaseDebt = spoke.baseDebt;
    if (existingBaseDebt == 0) return;

    // todo: add rayMulDiv in WadRayMath (=mulDiv / RAY) to optimize out the one cancelled RAY
    // & avoid precision loss
    uint256 cumulatedBaseDebt = spoke.baseDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      spoke.baseBorrowIndex
    );

    // todo carry out multiplication in rad (radMul) for precision
    spoke.outstandingPremium += (cumulatedBaseDebt - existingBaseDebt).percentMul(
      spoke.riskPremiumRad.radToBps()
    );
    spoke.baseDebt = cumulatedBaseDebt;
    spoke.baseBorrowIndex = nextBaseBorrowIndex;
    spoke.lastUpdateTimestamp = block.timestamp;
  }
}

// src/contracts/LiquidityHub.sol

struct SpokeData {
  uint256 suppliedShares; // share
  uint256 baseDebt; // asset
  uint256 outstandingPremium; // asset
  uint256 baseBorrowIndex; // in ray
  uint256 riskPremiumRad; // weighted average risk premium in rad (bps value with extra `rad` precision)
  uint256 lastUpdateTimestamp;
  DataTypes.SpokeConfig config;
}

struct Asset {
  uint256 id;
  uint256 suppliedShares; // share
  uint256 availableLiquidity; // asset
  uint256 baseDebt; // asset
  uint256 outstandingPremium; // asset
  uint256 baseBorrowIndex; // in ray
  uint256 baseBorrowRate; // in ray
  uint256 riskPremiumRad; // in rad
  uint256 lastUpdateTimestamp;
  DataTypes.AssetConfig config;
}

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for Asset;
  using SpokeDataLogic for SpokeData;

  mapping(uint256 assetId => Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spokeAddress => SpokeData spokeData)) internal _spokes;

  IERC20[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  //
  // External
  //

  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return _assets[assetId];
  }

  function getSpoke(uint256 assetId, address spoke) external view returns (SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return _spokes[assetId][spoke].config;
  }

  function getTotalAssets(uint256 assetId) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return asset.getTotalAssets();
  }

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig memory params, address asset) external {
    // TODO: AccessControl
    assetsList.push(IERC20(asset));
    _assets[assetCount] = Asset({
      id: assetCount,
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDebt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: WadRayMath.RAY,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      riskPremiumRad: 0,
      config: DataTypes.AssetConfig({
        decimals: params.decimals,
        active: params.active,
        irStrategy: params.irStrategy
      })
    });
    assetCount++;

    // TODO: emit event
  }

  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig memory params) external {
    // TODO: AccessControl
    _assets[assetId].config = DataTypes.AssetConfig({
      decimals: params.decimals,
      active: params.active,
      irStrategy: params.irStrategy
    });

    // TODO: emit event
  }

  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) external {
    // TODO: AccessControl
    _addSpoke(assetId, params, spoke);
  }

  function addSpokes(
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] memory configs,
    address spoke
  ) external {
    // TODO: AccessControl

    require(assetIds.length == configs.length, 'MISMATCHED_CONFIGS');
    for (uint256 i; i < assetIds.length; i++) {
      _addSpoke(assetIds[i], configs[i], spoke);
    }
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory params
  ) external {
    // TODO: AccessControl
    _spokes[assetId][spoke].config = DataTypes.SpokeConfig({
      drawCap: params.drawCap,
      supplyCap: params.supplyCap
    });

    // TODO: emit event
  }

  // /////
  // Users
  // /////

  /// @dev risk premium is calculated on the spoke and passed upon every action
  function supply(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremium,
    address supplier
  ) external returns (uint256, uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    uint256 nextBaseBorrowIndex = _accrueInterest(asset, spoke);
    _validateSupply(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});
    _updateRiskPremiumAndBaseDebt({
      asset: asset,
      spoke: spoke,
      newSpokeRiskPremium: riskPremium,
      baseDebtChange: 0
    });

    asset.availableLiquidity += amount;

    // todo: Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = asset.convertToSharesDown(amount);
    require(sharesAmount > 0, 'INVALID_AMOUNT');

    asset.suppliedShares += sharesAmount;
    spoke.suppliedShares += sharesAmount; // todo: mint 4626 shares to abstract this accounting

    // TODO: fee-on-transfer
    assetsList[assetId].safeTransferFrom(supplier, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return (nextBaseBorrowIndex, sharesAmount);
  }

  // TODO: Be able to pass max(uint) as amount to withdraw all or accept number of shares
  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremiumRad
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke); // accrue interest before validating action
    _validateWithdraw(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    _updateRiskPremiumAndBaseDebt(asset, spoke, riskPremiumRad, 0); // no base debt change

    asset.availableLiquidity -= amount;

    uint256 sharesAmount = asset.convertToSharesDown(amount);

    asset.suppliedShares -= sharesAmount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  function draw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremiumRad
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke); // accrue interest before validating action
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    _updateRiskPremiumAndBaseDebt(asset, spoke, riskPremiumRad, int256(amount)); // base debt added

    asset.availableLiquidity -= amount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    return amount;
  }

  /**
   * @notice Repays debt on behalf of user
   * @dev Only callable by spokes
   * @dev Interest is always paid off first from premium, then from base
   * @param assetId The asset id
   * @param amount The amount to repay
   * @param riskPremiumRad The aggregated risk premium of the calling spoke
   * @param repayer The address who is trying to settle the credit line
   * @return The amount of shares restored
   */
  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumRad,
    address repayer
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    _accrueInterest(asset, spoke); // accrue interest before validating action
    _validateRestore(asset, amount, spoke.baseDebt);
    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});

    uint256 baseDebtRestored = _deductFromOutstandingPremium(asset, spoke, amount);
    _updateRiskPremiumAndBaseDebt(asset, spoke, riskPremiumRad, -int256(baseDebtRestored));

    asset.availableLiquidity += amount;

    assetsList[assetId].safeTransferFrom(repayer, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return amount;
  }

  //
  // public
  //

  function previewNextBorrowIndex(uint256 assetId) public view returns (uint256) {
    (, uint256 nextBaseBorrowIndex) = _assets[assetId].previewNextBorrowIndex();
    return nextBaseBorrowIndex;
  }

  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesUp(assets);
  }

  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesDown(assets);
  }

  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsUp(shares);
  }

  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(shares);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].getInterestRate();
  }

  function getSpokeDrawnLiquidity(uint256 assetId, address spoke) public view returns (uint256) {
    return _spokes[assetId][spoke].baseDebt;
  }

  function getTotalDrawnLiquidity(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseDebt;
  }

  //
  // Internal
  //

  function _validateSupply(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(assetsList[asset.id] != IERC20(address(0)), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      spoke.config.supplyCap == type(uint256).max ||
        asset.convertToAssetsDown(spoke.suppliedShares) + amount <= spoke.config.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    // TODO: still allow withdrawal even if asset is not active, only prevent for frozen/paused?
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      amount <= asset.convertToAssetsDown(spoke.suppliedShares) - spoke.baseDebt,
      'SUPPLIED_AMOUNT_EXCEEDED'
    );
    require(amount <= asset.availableLiquidity, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateDraw(Asset storage asset, uint256 amount, uint256 drawCap) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      drawCap == type(uint256).max || amount + asset.baseDebt <= drawCap,
      'DRAW_CAP_EXCEEDED'
    );
    require(amount <= asset.availableLiquidity, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateRestore(
    Asset storage asset,
    uint256 amountRestored,
    uint256 amountDrawn
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // Ensure spoke is not restoring more than supplied
    require(amountRestored <= amountDrawn, 'INVALID_RESTORE_AMOUNT');
  }

  // @dev Utilizes existing asset & spoke: `baseBorrowIndex`, `riskPremiumRad`
  function _accrueInterest(
    Asset storage asset,
    SpokeData storage spoke
  ) internal returns (uint256) {
    (uint256 cumulatedBaseInterest, uint256 nextBaseBorrowIndex) = asset.previewNextBorrowIndex();
    asset.accrueInterest(cumulatedBaseInterest, nextBaseBorrowIndex);
    spoke.accrueInterest(nextBaseBorrowIndex);
    return nextBaseBorrowIndex;
  }

  // @dev Expects both `asset.baseDebt` & `spoke.baseDebt` have been accrued
  // @dev Does not update `outstandingPremium`
  function _updateRiskPremiumAndBaseDebt(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 newSpokeRiskPremium,
    int256 baseDebtChange
  ) internal {
    uint256 existingAssetDebt = asset.baseDebt;
    uint256 existingSpokeDebt = spoke.baseDebt;

    // weighted average risk premium of all spokes without current `spoke`
    (uint256 assetRiskPremiumWithoutCurrent, uint256 assetDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        asset.riskPremiumRad,
        existingAssetDebt,
        spoke.riskPremiumRad, // use current spoke risk premium
        existingSpokeDebt
      );

    uint256 newSpokeDebt = baseDebtChange > 0
      ? existingSpokeDebt + uint256(baseDebtChange) // debt added
      : // force underflow: only possible when spoke takes repays amount more than net drawn
      existingSpokeDebt - uint256(-baseDebtChange); // debt restored

    (uint256 newAssetRiskPremium, uint256 newAssetDebt) = MathUtils.addToWeightedAverage(
      assetRiskPremiumWithoutCurrent,
      assetDebtWithoutCurrent,
      newSpokeRiskPremium, // use new spoke risk premium
      newSpokeDebt
    );

    asset.baseDebt = newAssetDebt;
    spoke.baseDebt = newSpokeDebt;

    asset.riskPremiumRad = newAssetRiskPremium;
    spoke.riskPremiumRad = newSpokeRiskPremium;
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory params, address spoke) internal {
    require(spoke != address(0), 'INVALID_SPOKE');
    _spokes[assetId][spoke] = SpokeData({
      suppliedShares: 0,
      baseDebt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: WadRayMath.RAY,
      riskPremiumRad: 0,
      lastUpdateTimestamp: block.timestamp,
      config: DataTypes.SpokeConfig(params.supplyCap, params.drawCap)
    });
    emit SpokeAdded(assetId, spoke);
  }

  // @dev `amount` can cover at most spoke's outstanding premium
  function _deductFromOutstandingPremium(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount
  ) internal returns (uint256) {
    uint256 spokeOutstandingPremium = spoke.outstandingPremium;

    uint256 baseDebtRestored;

    if (amount > spokeOutstandingPremium) {
      baseDebtRestored = amount - spokeOutstandingPremium;
      spoke.outstandingPremium = 0;
      // underflow not possible bc of invariant: asset.outstandingPremium >= spoke.outstandingPremium
      asset.outstandingPremium -= spokeOutstandingPremium;
    } else {
      // no base debt is restored, only outstanding premium
      spoke.outstandingPremium -= amount;
      asset.outstandingPremium -= amount;
    }

    return baseDebtRestored;
  }
}
