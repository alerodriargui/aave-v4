// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHubInstance} from 'src/deployments/utils/interfaces/IHubInstance.sol';
import {ISpokeInstance} from 'src/deployments/utils/interfaces/ISpokeInstance.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

library DeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));
  bytes internal constant CREATE2_FACTORY_BYTECODE =
    hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3';

  error Create2DeploymentFailed();

  function loadCreate2Factory() internal {
    if (Create2Utils.isContractDeployed(Create2Utils.CREATE2_FACTORY)) {
      return;
    }
    vm.etch(Create2Utils.CREATE2_FACTORY, CREATE2_FACTORY_BYTECODE);
  }

  function _create2Deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    address computed = Create2Utils.computeCreate2Address(salt, bytecode);

    if (Create2Utils.isContractDeployed(computed)) {
      return computed;
    } else {
      bytes memory creationBytecode = abi.encodePacked(salt, bytecode);
      (, bytes memory returnData) = Create2Utils.CREATE2_FACTORY.call(creationBytecode);

      address deployedAt = address(uint160(bytes20(returnData)));
      require(deployedAt == computed, Create2DeploymentFailed());

      return deployedAt;
    }
  }

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal returns (ISpokeInstance) {
    return deploySpokeImplementation(oracle, maxUserReservesLimit, '');
  }

  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (ISpokeInstance spoke) {
    loadCreate2Factory();
    return
      ISpokeInstance(_create2Deploy(salt, _getSpokeInstanceInitCode(oracle, maxUserReservesLimit)));
  }

  function deploySpoke(
    address oracle,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      ISpoke(
        proxify(
          address(deploySpokeImplementation(oracle, maxUserReservesLimit, '')),
          proxyAdminOwner,
          initData
        )
      );
  }

  function getDeterministicSpokeInstanceAddress(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal returns (address) {
    return getDeterministicSpokeInstanceAddress(oracle, maxUserReservesLimit, '');
  }

  function getDeterministicSpokeInstanceAddress(
    address oracle,
    uint16 maxUserReservesLimit,
    bytes32 salt
  ) internal returns (address) {
    bytes32 initCodeHash = keccak256(_getSpokeInstanceInitCode(oracle, maxUserReservesLimit));

    loadCreate2Factory();
    return Create2Utils.computeCreate2Address(salt, initCodeHash);
  }

  function deployHubImplementation() internal returns (IHubInstance) {
    return deployHubImplementation('');
  }

  function deployHubImplementation(bytes32 salt) internal returns (IHubInstance) {
    loadCreate2Factory();
    return IHubInstance(_create2Deploy(salt, _getHubInstanceInitCode()));
  }

  function deployHub(address proxyAdminOwner, address authority) internal returns (IHub) {
    return
      IHub(
        proxify(
          address(deployHubImplementation()),
          proxyAdminOwner,
          abi.encodeCall(IHubInstance.initialize, (authority))
        )
      );
  }

  function deployHub(
    address proxyAdminOwner,
    address authority,
    bytes32 salt
  ) internal returns (IHub) {
    return
      IHub(
        proxify(
          address(deployHubImplementation(salt)),
          proxyAdminOwner,
          abi.encodeCall(IHubInstance.initialize, (authority))
        )
      );
  }

  function proxify(
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      impl,
      proxyAdminOwner,
      initData
    );
    return address(proxy);
  }

  function _getSpokeInstanceInitCode(
    address oracle,
    uint16 maxUserReservesLimit
  ) internal view returns (bytes memory) {
    return
      abi.encodePacked(
        vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
        abi.encode(oracle, maxUserReservesLimit)
      );
  }

  function _getHubInstanceInitCode() internal view returns (bytes memory) {
    return vm.getCode('src/hub/instances/HubInstance.sol:HubInstance');
  }
}
