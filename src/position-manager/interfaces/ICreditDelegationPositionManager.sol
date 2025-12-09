// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title ICreditDelegationPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling credit delegation actions.
interface ICreditDelegationPositionManager is IPositionManagerBase {
  /// @notice Thrown when the credit delegation allowance is insufficient.
  error InsufficientCreditDelegation(uint256 allowance, uint256 required);

  /// @notice Emitted when a credit delegation is given.
  event CreditDelegation(
    address indexed owner,
    address indexed spender,
    uint256 indexed reserveId,
    uint256 amount
  );

  /// @notice Approves a credit delegation allowance for a spender.
  /// @param spender The address of the spender to receive the allowance.
  /// @param reserveId The identifier of the reserve.
  /// @param amount The amount of allowance.
  function approveCreditDelegation(address spender, uint256 reserveId, uint256 amount) external;

  /// @notice Approves a credit delegation allowance for a spender via signature.
  /// @param params The structured CreditDelegation parameters.
  /// @param signature The signed bytes for the intent.
  function approveCreditDelegationWithSig(
    EIP712Types.CreditDelegation calldata params,
    bytes calldata signature
  ) external;

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

  /// @notice Returns the credit delegation allowance for a spender on behalf of an owner.
  /// @param owner The address of the owner.
  /// @param spender The address of the spender.
  /// @param reserveId The identifier of the reserve.
  /// @return The amount of credit delegation allowance.
  function creditDelegationAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256);

  /// @notice Returns the type hash for the CreditDelegation intent.
  function CREDIT_DELEGATION_TYPEHASH() external view returns (bytes32);
}
