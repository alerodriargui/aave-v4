// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

interface ICreditDelegationPositionManager is IPositionManagerBase {
  error InsufficientCreditDelegation();

  event CreditDelegation(
    address indexed owner,
    address indexed spender,
    uint256 indexed reserveId,
    uint256 amount
  );

  function approveCreditDelegation(address spender, uint256 reserveId, uint256 amount) external;

  function approveCreditDelegationWithSig(
    EIP712Types.CreditDelegation calldata params,
    bytes calldata signature
  ) external;

  function borrowOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  function creditDelegationAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256);

  /// @notice Returns the type hash for the CreditDelegation intent.
  function CREDIT_DELEGATION_TYPEHASH() external view returns (bytes32);
}
