// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BytecodeLoader} from 'tests/utils/BytecodeLoader.sol';

import {Create2Utils} from 'tests/Create2Utils.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';

/// @notice Helper to deploy Spoke from custom profile precompiled bytecode
contract DeploySpoke {
  /// @notice Deploys a proxified SpokeInstance contract using CREATE2 and the stored bytecode with the provided deployment arguments, and proxified using initialize arguments.
  /// @param deployArgs The constructor arguments for the SpokeInstance implementation contract, encoded as bytes.
  /// @param initArgs The initialization arguments for the TransparentUpgradeableProxy, encoded as bytes.
  /// @param salt The salt to use for the CREATE2 deployment, allowing for deterministic address generation.
  /// @return The address of the deployed SpokeInstance implementation
  /// @return The address of the deployed SpokeInstance proxy
  function deploySpoke(
    bytes memory deployArgs,
    bytes memory initArgs,
    bytes32 salt
  ) public returns (address, address) {
    Create2Utils.loadCreate2Factory();

    bytes memory bytecode = BytecodeLoader.loadSpokeInstanceBytecode();

    address impl = Create2Utils.create2Deploy(salt, abi.encodePacked(bytecode, deployArgs));
    address proxy = DeployUtils.proxify(impl, msg.sender, initArgs);

    return (impl, proxy);
  }
}
