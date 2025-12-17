// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

// import {Utils} from 'src/deployments/utils/libraries/Utils.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {
  Create2Utils,
  AaveV4DeployProcedureBase
} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {
  TransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';

contract AaveV4SpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradableSpokeInstance(
    address spokeProxyAdminOwner,
    address accessManager,
    address oracle
  ) internal returns (address spokeProxy, address spokeImplementation) {
    _validateZeroAddress(spokeProxyAdminOwner, 'spoke proxy admin owner');
    _validateZeroAddress(accessManager, 'access manager');
    _validateZeroAddress(oracle, 'oracle');
    spokeImplementation = Create2Utils.create2Deploy(
      SALT,
      abi.encodePacked(type(SpokeInstance).creationCode, abi.encode(oracle))
    );
    spokeProxy = Create2Utils.proxify(
      SALT,
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
