// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

// Libraries
import {MockERC20} from 'tests/mocks/MockERC20.sol';

// Contracts
import {Actor} from '../../shared/utils/Actor.sol';
import {HookAggregator} from '../hooks/HookAggregator.t.sol';

/// @title BaseHandler
/// @notice Contains common logic for all handlers
/// @dev inherits all suite assertions since per action assertions are implmenteds in the handlers
contract BaseHandler is HookAggregator {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         MODIFIERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      SHARED VARIABLES                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

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

  /// @notice Helper function to approve an amount of tokens to a spender, a proxy Actor
  function _approve(address token, Actor actor_, address spender, uint256 amount) internal {
    (bool ok, bytes memory ret) = actor_.proxy(
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
    token.call(abi.encodeCall(MockERC20.mint, (receiver, amount)));
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
