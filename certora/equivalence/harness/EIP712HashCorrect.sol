// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {EIP712Hash as SpokeEIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';
import {EIP712Hash as PositionManagerEIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';

contract EIP712HashCorrect {
  /// SPOKE ///
  function hashPositionManagerUpdate(
    ISpoke.PositionManagerUpdate calldata params
  ) public pure returns (bytes32) {
    return keccak256(abi.encode(SpokeEIP712Hash.POSITION_MANAGER_UPDATE, params));
  }

  function hashSetUserPositionManagers(
    ISpoke.SetUserPositionManagers calldata params
  ) external pure returns (bytes32) {
    bytes32[] memory updatesHashes = new bytes32[](params.updates.length);
    for (uint256 i = 0; i < params.updates.length; i++) {
      updatesHashes[i] = hashPositionManagerUpdate(params.updates[i]);
    }

    return
      keccak256(
        abi.encode(
          SpokeEIP712Hash.SET_USER_POSITION_MANAGERS_TYPEHASH,
          params.onBehalfOf,
          keccak256(abi.encodePacked(updatesHashes)),
          params.nonce,
          params.deadline
        )
      );
  }

  /// TOKENIZATION SPOKE ///
  function hashTokenizedDeposit(
    ITokenizationSpoke.TokenizedDeposit calldata params
  ) external pure returns (bytes32) {
    return keccak256(abi.encode(SpokeEIP712Hash.TOKENIZED_DEPOSIT_TYPEHASH, params));
  }

  function hashTokenizedMint(
    ITokenizationSpoke.TokenizedMint calldata params
  ) external pure returns (bytes32) {
    return keccak256(abi.encode(SpokeEIP712Hash.TOKENIZED_MINT_TYPEHASH, params));
  }

  function hashTokenizedWithdraw(
    ITokenizationSpoke.TokenizedWithdraw calldata params
  ) external pure returns (bytes32) {
    return keccak256(abi.encode(SpokeEIP712Hash.TOKENIZED_WITHDRAW_TYPEHASH, params));
  }

  function hashTokenizedRedeem(
    ITokenizationSpoke.TokenizedRedeem calldata params
  ) external pure returns (bytes32) {
    return keccak256(abi.encode(SpokeEIP712Hash.TOKENIZED_REDEEM_TYPEHASH, params));
  }

  /// SIGNATURE GATEWAY ///
  function hashSupply(ISignatureGateway.Supply calldata params) external pure returns (bytes32) {
    return keccak256(abi.encode(PositionManagerEIP712Hash.SUPPLY_TYPEHASH, params));
  }

  function hashWithdraw(
    ISignatureGateway.Withdraw calldata params
  ) external pure returns (bytes32) {
    return keccak256(abi.encode(PositionManagerEIP712Hash.WITHDRAW_TYPEHASH, params));
  }

  function hashBorrow(ISignatureGateway.Borrow calldata params) external pure returns (bytes32) {
    return keccak256(abi.encode(PositionManagerEIP712Hash.BORROW_TYPEHASH, params));
  }

  function hashRepay(ISignatureGateway.Repay calldata params) external pure returns (bytes32) {
    return keccak256(abi.encode(PositionManagerEIP712Hash.REPAY_TYPEHASH, params));
  }

  function hashSetUsingAsCollateral(
    ISignatureGateway.SetUsingAsCollateral calldata params
  ) external pure returns (bytes32) {
    return
      keccak256(abi.encode(PositionManagerEIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH, params));
  }

  function hashUpdateUserRiskPremium(
    ISignatureGateway.UpdateUserRiskPremium calldata params
  ) external pure returns (bytes32) {
    return
      keccak256(abi.encode(PositionManagerEIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH, params));
  }

  function hashUpdateUserDynamicConfig(
    ISignatureGateway.UpdateUserDynamicConfig calldata params
  ) external pure returns (bytes32) {
    return
      keccak256(abi.encode(PositionManagerEIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH, params));
  }
}
