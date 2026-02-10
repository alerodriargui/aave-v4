// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Test Contracts
import {Actor} from './Actor.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';

library ActorsUtils {
  uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
  uint256 constant INITIAL_BALANCE = 1e12;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           ACTORS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  /// @notice Deploy protocol actors and initialize their balances
  function setUpActors(
    address[] memory addresses,
    address[] memory tokens,
    address[] memory contracts
  ) internal returns (address[] memory actorAddresses) {
    actorAddresses = new address[](addresses.length);

    // Initialize the three actors of the fuzzers
    for (uint256 i; i < addresses.length; i++) {
      // Deploy actor proxies and approve system contracts
      address _actor = setUpActor(tokens, contracts);

      // Mint initial balances to actors
      for (uint256 j = 0; j < tokens.length; j++) {
        TestnetERC20 _token = TestnetERC20(tokens[j]);
        uint256 decimals = _token.decimals();
        _token.mint(_actor, INITIAL_BALANCE * 10 ** decimals);
      }
      actorAddresses[i] = _actor;
    }
  }

  /// @notice Deploy an actor proxy contract
  /// @param tokens Array of token addresses
  /// @param contracts Array of contract addresses to aprove tokens to
  /// @return actorAddress Address of the deployed actor
  function setUpActor(
    address[] memory tokens,
    address[] memory contracts
  ) internal returns (address actorAddress) {
    bool success;
    Actor _actor = new Actor(tokens, contracts);
    (success, ) = address(_actor).call{value: INITIAL_ETH_BALANCE}('');
    assert(success);
    actorAddress = address(_actor);
  }
}
