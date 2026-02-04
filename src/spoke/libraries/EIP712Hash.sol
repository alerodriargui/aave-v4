// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title EIP712Hash library
/// @author Aave Labs
/// @notice Helper methods to hash EIP712 typed data structs.
library EIP712Hash {
  bytes32 public constant SET_USER_POSITION_MANAGERS_TYPEHASH =
    // keccak256('SetUserPositionManagers(address onBehalfOf,PositionManagerUpdate[] updates,uint256 nonce,uint256 deadline)PositionManagerUpdate(address positionManager,bool approve)')
    0xba01f7bf3d3674c63670ec4a78b0d56aac1ad6e8c84468920b9e61bfe0b9851a;

  bytes32 public constant POSITION_MANAGER_UPDATE =
    // keccak256('PositionManagerUpdate(address positionManager,bool approve)')
    0x187dbd227227274b90655fb4011fc21dd749e8966fc040bd91e0b92609202565;

  function hash(
    ISpoke.SetUserPositionManagers calldata params
  ) internal pure returns (bytes32 digest) {
    assembly ('memory-safe') {
      // retrieve fmp; note: memory will be left dirtied
      let m := mload(0x40)

      let list := add(params, calldataload(add(params, 0x20))) // updates array offset
      let count := calldataload(list) // updates array size

      // store abi.encodePacked(updates.map(hash)) at `m`
      for {
        let i := 0
      } lt(i, count) {
        i := add(i, 1)
      } {
        let update := add(add(list, 0x20), mul(i, 0x40))

        mstore(0, POSITION_MANAGER_UPDATE)
        mstore(0x20, shr(96, shl(96, calldataload(update)))) // params.updates[i].positionManager
        mstore(0x40, iszero(iszero(calldataload(add(update, 0x20))))) // params.updates[i].approve

        mstore(add(m, mul(i, 0x20)), keccak256(0, 0x60))
      }

      let updatesDigest := keccak256(m, mul(count, 0x20))

      mstore(m, SET_USER_POSITION_MANAGERS_TYPEHASH)
      mstore(add(m, 0x20), shr(96, shl(96, calldataload(params)))) // params.onBehalfOf
      mstore(add(m, 0x40), updatesDigest) // keccak256(abi.encodePacked(updates.map(hash)))
      mstore(add(m, 0x60), calldataload(add(params, 0x40))) // params.nonce
      mstore(add(m, 0x80), calldataload(add(params, 0x60))) // params.deadline

      digest := keccak256(m, 0xa0)
      mstore(0x40, m) // restore fmp because we used it for the intermediate `update`s hash
    }
  }

  function hash(
    ISpoke.PositionManagerUpdate calldata params
  ) internal pure returns (bytes32 digest) {
    assembly ('memory-safe') {
      let m := mload(0x40)

      mstore(0, POSITION_MANAGER_UPDATE)
      mstore(0x20, shr(96, shl(96, calldataload(params)))) // params.positionManager
      mstore(0x40, iszero(iszero(calldataload(add(params, 0x20))))) // params.approve

      digest := keccak256(0, 0x60)
      mstore(0x40, m)
    }
  }
}
