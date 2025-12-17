// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {
  TransparentUpgradeableProxy
} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

library Create2Utils {
  // https://github.com/safe-global/safe-singleton-factory
  address public constant CREATE2_FACTORY = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

  error missingCreate2Factory();
  error create2AddressDerivationFailure();
  error nonceNotSupported();
  error failedCreate2FactoryCall();

  function create2Deploy(bytes32 salt, bytes memory bytecode) internal returns (address) {
    require(isContractDeployed(CREATE2_FACTORY), missingCreate2Factory());
    address computed = computeCreate2Address(salt, bytecode);
    if (isContractDeployed(computed)) {
      return computed;
    } else {
      bytes memory creationBytecode = abi.encodePacked(salt, bytecode);
      (bool success, bytes memory returnData) = CREATE2_FACTORY.call(creationBytecode);
      require(success, failedCreate2FactoryCall());
      address deployedAt = address(uint160(bytes20(returnData)));
      require(deployedAt == computed, create2AddressDerivationFailure());
      return deployedAt;
    }
  }

  function proxify(
    bytes32 salt,
    address logic,
    address initialOwner,
    bytes memory data
  ) internal returns (address) {
    return
      create2Deploy(
        salt,
        abi.encodePacked(
          type(TransparentUpgradeableProxy).creationCode,
          abi.encode(logic, initialOwner, data)
        )
      );
  }

  function isContractDeployed(address _addr) internal view returns (bool isContract) {
    return (_addr.code.length > 0);
  }

  function computeCreateAddress(address deployer, uint8 nonce) internal pure returns (address) {
    // RLP([deployer, nonce]) for 0 <= nonce <= 0x7f
    // nonce == 0 is encoded as the empty string (0x80) in RLP
    require(nonce < 0x80, nonceNotSupported());
    bytes1 nonceRlp = nonce == 0 ? bytes1(0x80) : bytes1(nonce);
    bytes memory rlp = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, nonceRlp);
    return address(uint160(uint256(keccak256(rlp))));
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes32 initcodeHash
  ) internal pure returns (address) {
    return
      addressFromLast20Bytes(
        keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, salt, initcodeHash))
      );
  }

  function computeCreate2Address(
    bytes32 salt,
    bytes memory bytecode
  ) internal pure returns (address) {
    return computeCreate2Address(salt, keccak256(abi.encodePacked(bytecode)));
  }

  function addressFromLast20Bytes(bytes32 bytesValue) internal pure returns (address) {
    return address(uint160(uint256(bytesValue)));
  }
}
