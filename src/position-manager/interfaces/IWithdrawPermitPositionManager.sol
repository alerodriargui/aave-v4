// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

interface IWithdrawPermitPositionManager is IPositionManagerBase {
  error InsufficientWithdrawAllowance();

  event WithdrawApproval(
    address indexed owner,
    address indexed spender,
    uint256 indexed reserveId,
    uint256 amount
  );

  function approveWithdraw(address spender, uint256 reserveId, uint256 amount) external;

  function approveWithdrawWithSig(
    EIP712Types.WithdrawPermit calldata params,
    bytes calldata signature
  ) external;

  function withdrawOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  function withdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256);

  /// @notice Returns the type hash for the WithdrawPermit intent.
  function WITHDRAW_PERMIT_TYPEHASH() external view returns (bytes32);
}
