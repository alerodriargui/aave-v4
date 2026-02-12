// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title ScriptUtils
/// @notice Shared utility functions for deploy scripts and deploy validation tests.
library ScriptUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  /// @notice Compare two strings for equality by hash.
  function strEq(string memory a, string memory b) internal pure returns (bool) {
    return keccak256(abi.encode(a)) == keccak256(abi.encode(b));
  }

  /// @notice Find the assetId for a token on a hub by linear scan.
  /// @dev Reverts if not found. Does not work if same token listed multiple times.
  function assetId(IHub hub, address token) internal view returns (uint256) {
    uint256 count = hub.getAssetCount();
    for (uint256 i; i < count; ++i) {
      if (hub.getAsset(i).underlying == token) return i;
    }
    revert('token not found');
  }

  /// @notice Return a substring starting at byte offset `x`.
  function slice(string memory input, uint256 x) internal pure returns (string memory) {
    bytes memory inputBytes = bytes(input);
    require(inputBytes.length >= x, 'Input too short');
    bytes memory result = new bytes(inputBytes.length - x);
    for (uint256 i = x; i < inputBytes.length; i++) {
      result[i - x] = inputBytes[i];
    }
    return string(result);
  }

  /// @notice Get the current git commit hash via FFI.
  function commit() internal returns (string memory) {
    string[] memory c = new string[](3);
    c[0] = 'git';
    c[1] = 'rev-parse';
    c[2] = 'HEAD';
    return slice(vm.toString(vm.ffi(c)), 2);
  }
}
