// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title ConfigReaderBaseTest
/// @notice Shared base for all ConfigReader scenario tests.
///         Imports ConfigReader, ISpoke, and IHub so child tests only need to import this file.
///         Provides helpers for string comparison, assertions, and section counting.
abstract contract ConfigReaderBaseTest is Test {
  using ConfigReader for string;

  string internal json;

  /// @notice Compare two strings for equality by keccak hash.
  function _strEq(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(bytes(a)) == keccak256(bytes(b));
  }

  /// @notice Assert a string field matches expected value.
  function _assertStr(
    string memory actual,
    string memory expected,
    string memory label
  ) internal pure {
    assertTrue(_strEq(actual, expected), string.concat(label, ': expected "', expected, '"'));
  }

  /// @notice Count items of a given type by iterating existence checks.
  function _countAssets() internal view returns (uint256 count) {
    while (json.assetExists(count)) {
      count++;
    }
  }

  function _countHubs() internal view returns (uint256 count) {
    while (json.hubExists(count)) {
      count++;
    }
  }

  function _countSpokes() internal view returns (uint256 count) {
    while (json.spokeExists(count)) {
      count++;
    }
  }

  function _countSpokeRegistrations() internal view returns (uint256 count) {
    while (json.spokeRegistrationExists(count)) {
      count++;
    }
  }

  function _countReserves() internal view returns (uint256 count) {
    while (json.reserveExists(count)) {
      count++;
    }
  }
}
