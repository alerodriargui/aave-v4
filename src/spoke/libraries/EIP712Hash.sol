// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
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

  bytes32 public constant TOKENIZED_DEPOSIT_TYPEHASH =
    // keccak256('TokenizedDeposit(address depositor,uint256 assets,address receiver,uint256 nonce,uint256 deadline)')
    0xdecc632fabbd6d9f578203db4396740eb2d81cf0fd7681b726d116e49cbc240c;

  bytes32 public constant TOKENIZED_MINT_TYPEHASH =
    // keccak256('TokenizedMint(address depositor,uint256 shares,address receiver,uint256 nonce,uint256 deadline)')
    0x12737e595645af6fb99e7985f3dff6fb716ac1ec517c0d2b21313985dc207343;

  bytes32 public constant TOKENIZED_WITHDRAW_TYPEHASH =
    // keccak256('TokenizedWithdraw(address owner,uint256 assets,address receiver,uint256 nonce,uint256 deadline)')
    0xe81b79af873473ec5cb79baa56499159fca87ff2e3333f24183127408a14acb5;

  bytes32 public constant TOKENIZED_REDEEM_TYPEHASH =
    // keccak256('TokenizedRedeem(address owner,uint256 shares,address receiver,uint256 nonce,uint256 deadline)')
    0x03929148275eed00e4c3ef9c0ee72e49ec6cb96c7a34941708e052f9a511334e;

  bytes32 public constant PERMIT_TYPEHASH =
    // keccak256('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
    0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

  function hash(
    ISpoke.SetUserPositionManagers calldata params
  ) internal pure returns (bytes32 digest) {
    assembly {
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
    // equivalent to: keccak256(abi.encode(POSITION_MANAGER_UPDATE, params.positionManager, params.approve))
    assembly {
      let fmp := mload(0x40)
      mstore(0, POSITION_MANAGER_UPDATE)
      mstore(0x20, shr(96, shl(96, calldataload(params)))) // params.positionManager
      mstore(0x40, iszero(iszero(calldataload(add(params, 0x20))))) // params.approve
      digest := keccak256(0, 0x60)
      mstore(0x40, fmp)
    }
  }

  function hash(
    ITokenizationSpoke.TokenizedDeposit calldata params
  ) internal pure returns (bytes32 digest) {
    assembly ('memory-safe') {
      // retrieve fmp; note: memory will be left dirtied
      let m := mload(0x40)

      mstore(m, TOKENIZED_DEPOSIT_TYPEHASH)
      mstore(add(m, 0x20), shr(96, shl(96, calldataload(params)))) // params.depositor
      mstore(add(m, 0x40), calldataload(add(params, 0x20))) // params.assets
      mstore(add(m, 0x60), shr(96, shl(96, calldataload(add(params, 0x40))))) // params.receiver
      mstore(add(m, 0x80), calldataload(add(params, 0x60))) // params.nonce
      mstore(add(m, 0xa0), calldataload(add(params, 0x80))) // params.deadline

      digest := keccak256(m, 0xc0)
    }
  }

  function hash(
    ITokenizationSpoke.TokenizedMint calldata params
  ) internal pure returns (bytes32 digest) {
    assembly ('memory-safe') {
      // retrieve fmp; note: memory will be left dirtied
      let m := mload(0x40)

      mstore(m, TOKENIZED_MINT_TYPEHASH)
      mstore(add(m, 0x20), shr(96, shl(96, calldataload(params)))) // params.depositor
      mstore(add(m, 0x40), calldataload(add(params, 0x20))) // params.shares
      mstore(add(m, 0x60), shr(96, shl(96, calldataload(add(params, 0x40))))) // params.receiver
      mstore(add(m, 0x80), calldataload(add(params, 0x60))) // params.nonce
      mstore(add(m, 0xa0), calldataload(add(params, 0x80))) // params.deadline

      digest := keccak256(m, 0xc0)
    }
  }

  function hash(
    ITokenizationSpoke.TokenizedWithdraw calldata params
  ) internal pure returns (bytes32 digest) {
    assembly ('memory-safe') {
      // retrieve fmp; note: memory will be left dirtied
      let m := mload(0x40)

      mstore(m, TOKENIZED_WITHDRAW_TYPEHASH)
      mstore(add(m, 0x20), shr(96, shl(96, calldataload(params)))) // params.owner
      mstore(add(m, 0x40), calldataload(add(params, 0x20))) // params.assets
      mstore(add(m, 0x60), shr(96, shl(96, calldataload(add(params, 0x40))))) // params.receiver
      mstore(add(m, 0x80), calldataload(add(params, 0x60))) // params.nonce
      mstore(add(m, 0xa0), calldataload(add(params, 0x80))) // params.deadline

      digest := keccak256(m, 0xc0)
    }
  }

  function hash(
    ITokenizationSpoke.TokenizedRedeem calldata params
  ) internal pure returns (bytes32 digest) {
    assembly ('memory-safe') {
      // retrieve fmp; note: memory will be left dirtied
      let m := mload(0x40)

      mstore(m, TOKENIZED_REDEEM_TYPEHASH)
      mstore(add(m, 0x20), shr(96, shl(96, calldataload(params)))) // params.owner
      mstore(add(m, 0x40), calldataload(add(params, 0x20))) // params.shares
      mstore(add(m, 0x60), shr(96, shl(96, calldataload(add(params, 0x40))))) // params.receiver
      mstore(add(m, 0x80), calldataload(add(params, 0x60))) // params.nonce
      mstore(add(m, 0xa0), calldataload(add(params, 0x80))) // params.deadline

      digest := keccak256(m, 0xc0)
    }
  }
}
