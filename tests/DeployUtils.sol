// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

library DeployUtils {
  // https://github.com/safe-global/safe-singleton-factory
  address public constant CREATE2_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;
  bytes internal constant CREATE2_FACTORY_BYTECODE =
    hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3';

  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  error NoCreate2Factory();
  error Create2DeploymentFailed();

  function deploySpokeInstance(address oracle) internal returns (ISpoke) {
    return deploySpokeInstance(oracle, '');
  }

  function deploySpokeInstance(address oracle, bytes32 salt) internal returns (ISpoke spoke) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      abi.encode(oracle)
    );
    return ISpoke(_create2Deploy(salt, initCode));
  }

  function deployProxifiedSpokeInstance(
    address deployer,
    address oracle,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      ISpoke(_proxify(deployer, address(deploySpokeInstance(oracle)), proxyAdminOwner, initData));
  }

  function getDeterministicSpokeInstanceAddress(address oracle) internal view returns (address) {
    return getDeterministicSpokeInstanceAddress(oracle, '');
  }

  function getDeterministicSpokeInstanceAddress(
    address oracle,
    bytes32 salt
  ) internal view returns (address) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/spoke/instances/SpokeInstance.sol:SpokeInstance'),
      abi.encode(oracle)
    );
    bytes32 initCodeHash = keccak256(initCode);
    return computeCreate2Address(salt, initCodeHash);
  }

  function deployHub(address authority) internal returns (IHub) {
    return deployHub(authority, '');
  }

  function deployHub(address authority, bytes32 salt) internal returns (IHub hub) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/hub/Hub.sol:Hub'),
      abi.encode(authority)
    );
    return IHub(_create2Deploy(salt, initCode));
  }

  function getDeterministicHubAddress(address authority) internal view returns (address) {
    return getDeterministicHubAddress(authority, '');
  }

  function getDeterministicHubAddress(
    address authority,
    bytes32 salt
  ) internal view returns (address) {
    bytes memory initCode = abi.encodePacked(
      vm.getCode('src/hub/Hub.sol:Hub'),
      abi.encode(authority)
    );
    bytes32 initCodeHash = keccak256(initCode);
    return computeCreate2Address(salt, initCodeHash);
  }

  function setCreate2Factory() internal {
    vm.etch(CREATE2_FACTORY, CREATE2_FACTORY_BYTECODE);
  }

  function _create2Deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    if (isContractDeployed(CREATE2_FACTORY) == false) {
      revert NoCreate2Factory();
    }

    address computed = computeCreate2Address(salt, bytecode);

    if (isContractDeployed(computed)) {
      return computed;
    } else {
      bytes memory creationBytecode = abi.encodePacked(salt, bytecode);
      bytes memory returnData;
      (, returnData) = CREATE2_FACTORY.call(creationBytecode);

      address deployedAt = address(uint160(bytes20(returnData)));
      require(deployedAt == computed, Create2DeploymentFailed());

      return deployedAt;
    }
  }

  function isContractDeployed(address _addr) internal view returns (bool isContract) {
    return (_addr.code.length > 0);
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes32 initcodeHash
  ) internal pure returns (address) {
    return
      address(
        uint160(
          uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, salt, initcodeHash)))
        )
      );
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes memory bytecode
  ) internal pure returns (address) {
    return computeCreate2Address(salt, keccak256(abi.encodePacked(bytecode)));
  }

  function _proxify(
    address deployer,
    address impl,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (address) {
    vm.prank(deployer);
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
      impl,
      proxyAdminOwner,
      initData
    );
    return address(proxy);
  }
}
