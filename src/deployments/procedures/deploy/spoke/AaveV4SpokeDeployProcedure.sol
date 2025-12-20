// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {
  TransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';

contract AaveV4SpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradableSpokeInstance(
    address spokeProxyAdminOwner,
    address accessManager,
    address oracle,
    bytes32 salt
  ) internal returns (address spokeProxy, address spokeImplementation) {
    require(spokeProxyAdminOwner != address(0), 'invalid spoke proxy admin owner');
    require(accessManager != address(0), 'invalid access manager');
    require(oracle != address(0), 'invalid oracle');
    spokeImplementation = Create2Utils.create2Deploy(
      salt,
      abi.encodePacked(type(SpokeInstance).creationCode, abi.encode(oracle))
    );
    spokeProxy = Create2Utils.proxify(
      salt,
      spokeImplementation,
      spokeProxyAdminOwner,
      abi.encodeCall(SpokeInstance.initialize, (accessManager))
    );
    return (spokeProxy, spokeImplementation);
  }

  function _computeSpokeInstanceAddress(
    bytes32 salt,
    address oracle,
    address spokeProxyAdminOwner,
    address accessManager
  ) internal pure returns (address) {
    address spokeImplementation = Create2Utils.computeCreate2Address(
      salt,
      abi.encodePacked(type(SpokeInstance).creationCode, abi.encode(oracle))
    );
    bytes memory initCode = abi.encodePacked(
      type(TransparentUpgradeableProxy).creationCode,
      abi.encode(
        spokeImplementation,
        spokeProxyAdminOwner,
        abi.encodeCall(SpokeInstance.initialize, (accessManager))
      )
    );
    return Create2Utils.computeCreate2Address(salt, keccak256(initCode));
  }
}
