// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Vm} from 'forge-std/Vm.sol';
import {MockERC20} from 'tests/mocks/MockERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {Actor} from './Actor.sol';

Vm constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));
uint256 constant UINT256_MAX = type(uint256).max;

contract CommonHelpers {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         HELPERS                                           //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Helper function to randomize a uint256 seed with a string salt
  function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
    return uint256(keccak256(abi.encodePacked(seed, salt)));
  }

  /// @notice Helper function to get a random value
  function _getRandomValue(uint256 modulus) internal view returns (uint256) {
    uint256 randomNumber = uint256(
      keccak256(abi.encode(block.timestamp, block.prevrandao, msg.sender))
    );
    return randomNumber % modulus; // Adjust the modulus to the desired range
  }

  /// @notice Helper function to bound a value between a min and max
  /// @dev Taken from forge-std's stdUtils, renamed to avoid conflict with forge-std's import on foundry replays.
  function _bound2(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
    assert(min <= max);
    // If x is between min and max, return x directly. This is to ensure that dictionary values
    // do not get shifted if the min is nonzero. More info: https://github.com/foundry-rs/forge-std/issues/188
    if (x >= min && x <= max) return x;

    uint256 size = max - min + 1;

    // If the value is 0, 1, 2, 3, wrap that to min, min+1, min+2, min+3. Similarly for the UINT256_MAX side.
    // This helps ensure coverage of the min/max values.
    if (x <= 3 && size > x) return min + x;
    if (x >= UINT256_MAX - 3 && size > UINT256_MAX - x) return max - (UINT256_MAX - x);

    // Otherwise, wrap x into the range [min, max], i.e. the range is inclusive.
    if (x > max) {
      uint256 diff = x - max;
      uint256 rem = diff % size;
      if (rem == 0) return max;
      return min + rem - 1;
    } else if (x < min) {
      uint256 diff = min - x;
      uint256 rem = diff % size;
      if (rem == 0) return min;
      return max - rem + 1;
    }
    return x; // This should never be reached due to the first check, but is needed to silence compiler warnings.
  }

  /// @notice Helper function to approve an amount of tokens to a spender, a proxy Actor
  function _approve(address token, Actor actor, address spender, uint256 amount) internal {
    (bool ok, bytes memory ret) = actor.proxy(
      token,
      abi.encodeCall(IERC20.approve, (spender, amount))
    );
    require(ok, string(ret));
  }

  /// @notice Helper function to safely approve an amount of tokens to a spender
  function _approve(address token, address owner, address spender, uint256 amount) internal {
    vm.prank(owner);
    _safeApprove(token, spender, 0);
    vm.prank(owner);
    _safeApprove(token, spender, amount);
  }

  /// @notice Helper function to safely approve an amount of tokens to a spender
  /// @dev This function is used to revert on failed approvals
  function _safeApprove(address token, address spender, uint256 amount) internal {
    (bool ok, bytes memory ret) = token.call(abi.encodeCall(IERC20.approve, (spender, amount)));
    assert(ok);
    if (ret.length > 0) assert(abi.decode(ret, (bool)));
  }

  /// @notice Helper function to mint an amount of tokens to an address
  function _mint(address token, address receiver, uint256 amount) internal {
    MockERC20(token).mint(receiver, amount);
  }

  /// @notice Helper function to mint an amount of tokens to an address and approve them to a spender
  /// @param token Address of the token to mint
  /// @param owner Address of the new owner of the tokens
  /// @param spender Address of the spender to approve the tokens to
  /// @param amount Amount of tokens to mint and approve
  function _mintAndApprove(address token, address owner, address spender, uint256 amount) internal {
    _mint(token, owner, amount);
    _approve(token, owner, spender, amount);
  }

  /// @notice Best-effort mint — silently swallows overflow so the handler can proceed.
  /// @dev Using a low-level call prevents the handler from reverting on mint failure
  ///      (e.g. totalSupply overflow), which would cause the fuzzer to discard the
  ///      entire call sequence. Spoke functions bound the passed amount to the user's
  ///      actual balance (e.g. repay(type(uint256).max) repays only the owed debt),
  ///      so even if minting the full amount overflows, the spoke will operate on
  ///      whatever balance exists.
  function _tryMint(address token, address receiver, uint256 amount) internal {
    (bool ok, ) = token.call(abi.encodeCall(MockERC20.mint, (receiver, amount)));
    ok; // suppress compiler warning
  }

  /// @notice Best-effort mint + approve for spoke handlers
  function _tryMintAndApprove(
    address token,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    _tryMint(token, owner, amount);
    _approve(token, owner, spender, amount);
  }
}
