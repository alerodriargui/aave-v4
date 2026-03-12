// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Vm} from 'forge-std/Vm.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeInstance} from 'tests/mocks/ISpokeInstance.sol';
import {Create2Utils} from 'tests/Create2Utils.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';

library SpokeDeployUtils {
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  // ==================== Spoke Deployment ====================

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
  ) internal returns (ISpokeInstance) {
    Create2Utils.loadCreate2Factory();
    return
      ISpokeInstance(
        Create2Utils.create2Deploy(salt, _getSpokeInstanceInitCode(oracle, maxUserReservesLimit))
      );
  }

  function deploySpoke(
    address oracle,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes memory initData
  ) internal returns (ISpoke) {
    return
      ISpoke(
        DeployUtils.proxify(
          address(deploySpokeImplementation(oracle, maxUserReservesLimit)),
          proxyAdminOwner,
          initData
        )
      );
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

  // ==================== Library Deployment ====================

  function deployLiquidationLogic() internal returns (address) {
    Create2Utils.loadCreate2Factory();
    bytes memory bytecode = vm.getCode('src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic');
    return Create2Utils.create2Deploy(bytes32(0), bytecode);
  }

  function getLibraryString(address liquidationLogic) internal pure returns (string memory) {
    return
      string(
        abi.encodePacked(
          'src/spoke/libraries/LiquidationLogic.sol:LiquidationLogic:',
          vm.toString(liquidationLogic)
        )
      );
  }

  function _deployAndWriteLibrariesConfig() internal {
    address liquidationLogic = deployLiquidationLogic();

    string memory librariesSolcString = getLibraryString(liquidationLogic);

    string memory sedCommand = string(
      abi.encodePacked('echo FOUNDRY_LIBRARIES=', librariesSolcString, ' >> .env')
    );
    string[] memory command = new string[](3);

    command[0] = 'bash';
    command[1] = '-c';
    command[2] = string(abi.encodePacked('response="$(', sedCommand, ')"; $response;'));
    vm.ffi(command);
  }

  // ==================== FfiUtils ====================

  function _librariesPathExists() internal returns (bool) {
    string
      memory checkCommand = '[ -e .env ] && grep -q "FOUNDRY_LIBRARIES" .env && echo true || echo false';
    string[] memory command = new string[](3);

    command[0] = 'bash';
    command[1] = '-c';
    command[2] = string(
      abi.encodePacked(
        'response="$(',
        checkCommand,
        ')"; cast abi-encode "response(bool)" $response;'
      )
    );
    bytes memory res = vm.ffi(command);

    bool found = abi.decode(res, (bool));

    return found;
  }

  function _deleteLibrariesPath() internal {
    // Keep sed OSX vs gnu sed compatibility
    string memory deleteCommand = "sed -i.bak -r '/FOUNDRY_LIBRARIES/d' .env && rm .env.bak";
    string[] memory delCommand = new string[](3);

    delCommand[0] = 'bash';
    delCommand[1] = '-c';
    delCommand[2] = string(abi.encodePacked('response="$(', deleteCommand, ')"; $response;'));
    vm.ffi(delCommand);
  }

  function _getLiquidationLogicAddress() internal returns (address) {
    string memory getLibraryAddress = "sed -nr 's/.*LiquidationLogic:([^,]*).*/\\1/p' .env";
    string[] memory getAddressCommand = new string[](3);

    getAddressCommand[0] = 'bash';
    getAddressCommand[1] = '-c';
    getAddressCommand[2] = string(
      abi.encodePacked(
        'response="$(',
        getLibraryAddress,
        ')"; [ -z "$response" ] && cast abi-encode "response(address)" 0x0000000000000000000000000000000000000000 || cast abi-encode "response(address)" $response'
      )
    );

    bytes memory res = vm.ffi(getAddressCommand);
    address lastLib = abi.decode(res, (address));
    return lastLib;
  }
}
