// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';

contract AaveV4SpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradableSpokeInstance(
    address spokeProxyAdminOwner,
    address authority,
    address oracle,
    bytes memory spokeBytecode,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address spokeProxy, address spokeImplementation) {
    require(spokeProxyAdminOwner != address(0), 'invalid spoke proxy admin owner');
    require(authority != address(0), 'invalid authority');
    require(oracle != address(0), 'invalid oracle');
    require(maxUserReservesLimit > 0, 'invalid max user reserves limit');
    spokeImplementation = Create2Utils.create2Deploy(
      salt,
      _getSpokeInstanceInitCode(spokeBytecode, oracle, maxUserReservesLimit)
    );
    spokeProxy = Create2Utils.proxify(
      salt,
      spokeImplementation,
      spokeProxyAdminOwner,
      abi.encodeCall(ISpokeInstance.initialize, (authority))
    );
    return (spokeProxy, spokeImplementation);
  }

  function _computeSpokeInstanceAddress(
    bytes32 salt,
    bytes memory spokeBytecode,
    address oracle,
    uint16 maxUserReservesLimit,
    address spokeProxyAdminOwner,
    address authority
  ) internal pure returns (address) {
    address spokeImplementation = Create2Utils.computeCreate2Address(
      salt,
      _getSpokeInstanceInitCode(spokeBytecode, oracle, maxUserReservesLimit)
    );
    bytes memory initCode = abi.encodePacked(
      type(TransparentUpgradeableProxy).creationCode,
      abi.encode(
        spokeImplementation,
        spokeProxyAdminOwner,
        abi.encodeCall(ISpokeInstance.initialize, (authority))
      )
    );
    return Create2Utils.computeCreate2Address(salt, keccak256(initCode));
  }

  function _getSpokeInstanceInitCode(
    bytes memory spokeBytecode,
    address oracle,
    uint16 maxUserReservesLimit
  ) internal pure returns (bytes memory) {
    return abi.encodePacked(spokeBytecode, abi.encode(oracle, maxUserReservesLimit));
  }
}
