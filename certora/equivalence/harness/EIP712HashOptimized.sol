// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {EIP712Hash as SpokeEIP712Hash} from 'src/spoke/libraries/EIP712Hash.sol';
import {EIP712Hash as PositionManagerEIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';

contract EIP712HashOptimized {
  using SpokeEIP712Hash for *;
  using PositionManagerEIP712Hash for *;

  /// SPOKE ///
  function hashPositionManagerUpdate(
    ISpoke.PositionManagerUpdate calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashSetUserPositionManagers(
    ISpoke.SetUserPositionManagers calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  /// TOKENIZATION SPOKE ///
  function hashTokenizedDeposit(
    ITokenizationSpoke.TokenizedDeposit calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashTokenizedMint(
    ITokenizationSpoke.TokenizedMint calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashTokenizedWithdraw(
    ITokenizationSpoke.TokenizedWithdraw calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashTokenizedRedeem(
    ITokenizationSpoke.TokenizedRedeem calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  /// SIGNATURE GATEWAY ///
  function hashSupply(ISignatureGateway.Supply calldata params) external pure returns (bytes32) {
    return params.hash();
  }

  function hashWithdraw(
    ISignatureGateway.Withdraw calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashBorrow(ISignatureGateway.Borrow calldata params) external pure returns (bytes32) {
    return params.hash();
  }

  function hashRepay(ISignatureGateway.Repay calldata params) external pure returns (bytes32) {
    return params.hash();
  }

  function hashSetUsingAsCollateral(
    ISignatureGateway.SetUsingAsCollateral calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashUpdateUserRiskPremium(
    ISignatureGateway.UpdateUserRiskPremium calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }

  function hashUpdateUserDynamicConfig(
    ISignatureGateway.UpdateUserDynamicConfig calldata params
  ) external pure returns (bytes32) {
    return params.hash();
  }
}
