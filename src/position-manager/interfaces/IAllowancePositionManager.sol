// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title IAllowancePositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling withdraw permit & credit delegation actions.
interface IAllowancePositionManager is IPositionManagerBase {
  /// @notice Thrown when the withdraw allowance is insufficient.
  error InsufficientWithdrawAllowance(uint256 allowance, uint256 required);
  /// @notice Thrown when the credit delegation allowance is insufficient.
  error InsufficientCreditDelegation(uint256 allowance, uint256 required);

  /// @notice Emitted when `owner` approves `spender` to withdraw `amount` for `reserveId` on their behalf.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param reserveId The identifier of the reserve on the connected `spoke`.
  /// @param amount The amount of allowance.
  event WithdrawApproval(
    address indexed owner,
    address indexed spender,
    uint256 indexed reserveId,
    uint256 amount
  );

  /// @notice Emitted when `owner` approves `spender` to borrow `amount` from `reserveId` on their behalf.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param reserveId The identifier of the reserve on the connected `spoke`.
  /// @param amount The amount of credit delegation.
  event CreditDelegation(
    address indexed owner,
    address indexed spender,
    uint256 indexed reserveId,
    uint256 amount
  );

  /// @notice Approves a spender to withdraw assets from the specified reserve on the connected `spoke`.
  /// @param spender The address of the spender to receive the allowance.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of allowance.
  function approveWithdraw(address spender, uint256 reserveId, uint256 amount) external;

  /// @notice Approves a spender to withdraw assets from the specified reserve on the connected `spoke` via signature.
  /// @param params The structured WithdrawPermit parameters.
  /// @param signature The signed bytes for the intent.
  function approveWithdrawWithSig(
    EIP712Types.WithdrawPermit calldata params,
    bytes calldata signature
  ) external;

  /// @notice Temporarily approves a spender to withdraw assets from the specified reserve on the spoke.
  /// @dev The allowance is discarded after the transaction.
  /// @param spender The address of the spender to receive the allowance.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of allowance.
  function temporaryApproveWithdraw(address spender, uint256 reserveId, uint256 amount) external;

  /// @notice Approves a credit delegation allowance for a spender.
  /// @param spender The address of the spender to receive the allowance.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of allowance.
  function delegateCredit(address spender, uint256 reserveId, uint256 amount) external;

  /// @notice Approves a credit delegation allowance for a spender via signature.
  /// @param params The structured CreditDelegation parameters.
  /// @param signature The signed bytes for the intent.
  function delegateCreditWithSig(
    EIP712Types.CreditDelegation calldata params,
    bytes calldata signature
  ) external;

  /// @notice Temporarily approves a credit delegation allowance for a spender.
  /// @dev The allowance is discarded after the transaction.
  /// @param spender The address of the spender to receive the allowance.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of allowance.
  function temporaryDelegateCredit(address spender, uint256 reserveId, uint256 amount) external;

  /// @notice Renounces the withdraw allowance given by the owner.
  /// @param owner The address of the owner.
  /// @param reserveId The identifier of the reserve.
  function renounceWithdrawAllowance(address owner, uint256 reserveId) external;

  /// @notice Renounces the credit delegation allowance given by the owner.
  /// @param owner The address of the owner.
  /// @param reserveId The identifier of the reserve.
  function renounceCreditDelegation(address owner, uint256 reserveId) external;

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

  /// @notice Executes a borrow on behalf of a user.
  /// @dev The caller must have sufficient credit delegation allowance from `onBehalfOf`.
  /// @dev The caller receives the borrowed assets.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount to borrow.
  /// @param onBehalfOf The address of the user to borrow on behalf of.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowOnBehalfOf(
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

  /// @notice Returns the credit delegation allowance for a spender on behalf of an owner.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of credit delegation allowance.
  function creditDelegation(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256);

  /// @notice Returns the EIP712 domain separator.
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /// @notice Returns the type hash for the WithdrawPermit intent.
  function WITHDRAW_PERMIT_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the CreditDelegation intent.
  function CREDIT_DELEGATION_TYPEHASH() external view returns (bytes32);
}
