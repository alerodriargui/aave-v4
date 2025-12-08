// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IMulticall} from 'src/interfaces/IMulticall.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';

interface IPositionManagerBase is IMulticall {
  /// @notice Thrown when the specified address is invalid.
  error InvalidAddress();
  /// @notice Thrown when signature deadline has passed or signer is not `onBehalfOf`.
  error InvalidSignature();

  /// @notice Facilitates setting this gateway as user position manager on the `spoke`
  /// with a typed signature from `user`.
  /// @dev The signature is consumed on the `spoke`.
  /// @dev The given data is passed to the `spoke` for the signature to be verified.
  /// @param params The structured setSelfAsUserPositionManager parameters.
  /// @param signature The signed bytes for the intent.
  function setSelfAsUserPositionManagerWithSig(
    EIP712Types.SetUserPositionManager calldata params,
    bytes calldata signature
  ) external;

  /// @notice Facilitates consuming a permit for the given reserve's underlying asset on the `spoke`.
  /// @dev The given data is passed to the underlying asset for the signature to be verified.
  /// @dev Spender is this gateway contract.
  /// @param reserveId The identifier of the reserve.
  /// @param onBehalfOf The address of the user on whose behalf the permit is being used.
  /// @param value The amount of the underlying asset to permit.
  /// @param deadline The deadline for the permit.
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external;

  function SPOKE() external view returns (ISpoke);
}
