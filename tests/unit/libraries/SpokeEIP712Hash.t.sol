// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {EIP712Hash as SpokeEIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';

contract SpokeEIP712HashTest is Test {
  using SpokeEIP712Hash for *;

  function test_constants() public pure {
    assertEq(
      SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      keccak256(
        'SetUserPositionManagers(address onBehalfOf,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)'
      )
    );
    assertEq(
      SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
      vm.eip712HashType('SetUserPositionManagers')
    );

    assertEq(
      SpokeEIP712Hash.POSITION_MANAGER_UPDATE,
      keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    );
    assertEq(SpokeEIP712Hash.POSITION_MANAGER_UPDATE, vm.eip712HashType('PositionManagerUpdate'));
  }

  function test_hash_setUserPositionManagers_fuzz(
    ISpoke.SetUserPositionManagers calldata params
  ) public pure {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < updatesHashes.length; ++i) {
      updatesHashes[i] = params.updates[i].hash();
    }

    bytes32 expectedHash = keccak256(
      abi.encode(
        SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
        params.onBehalfOf,
        keccak256(abi.encodePacked(updatesHashes)),
        params.nonce,
        params.deadline
      )
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('SetUserPositionManagers', abi.encode(params)));
  }

  function test_hash_positionManagerUpdate_fuzz(
    ISpoke.PositionManagerUpdate calldata params
  ) public pure {
    bytes32 expectedHash = keccak256(
      abi.encode(SpokeEIP712Hash.POSITION_MANAGER_UPDATE, params.positionManager, params.approve)
    );

    assertEq(params.hash(), expectedHash);
    assertEq(params.hash(), vm.eip712HashStruct('PositionManagerUpdate', abi.encode(params)));
  }
}
