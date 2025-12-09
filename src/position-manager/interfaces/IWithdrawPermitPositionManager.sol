// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title IWithdrawPermitPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling withdraw permit actions.
interface IWithdrawPermitPositionManager is IPositionManagerBase {
  /// @notice Thrown when the withdraw allowance is insufficient.
  error InsufficientWithdrawAllowance(uint256 allowance, uint256 required);

  /// @notice Emitted when a withdraw permit allowance is given.
  event WithdrawApproval(
    address indexed owner,
    address indexed spender,
    uint256 indexed reserveId,
    uint256 amount
  );

  /// @notice Approves a withdraw allowance for a spender.
  /// @param spender The address of the spender to receive the allowance.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of allowance.
  function approveWithdraw(address spender, uint256 reserveId, uint256 amount) external;

  /// @notice Approves a withdraw allowance for a spender via signature.
  /// @param params The structured WithdrawPermit parameters.
  /// @param signature The signed bytes for the intent.
  function approveWithdrawWithSig(
    EIP712Types.WithdrawPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Executes a withdraw on behalf of a user.
  /// @dev The caller must have sufficient withdraw allowance from `onBehalfOf`.
  /// @dev The caller receives the withdrawn assets.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to withdraw.
  /// @param onBehalfOf The address of the user to withdraw on behalf of.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256);

  /// @notice Returns the withdraw allowance for a spender on behalf of an owner.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of withdraw allowance.
  function withdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256);

  /// @notice Returns the type hash for the WithdrawPermit intent.
  function WITHDRAW_PERMIT_TYPEHASH() external view returns (bytes32);
}
