// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title PositionManagerBase
/// @author Aave Labs
/// @notice Base implementation for position manager common functionalities.
abstract contract PositionManagerBase is IPositionManagerBase, Multicall {
  /// @inheritdoc IPositionManagerBase
  address public immutable override SPOKE;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) {
    require(spoke_ != address(0), InvalidAddress());
    SPOKE = spoke_;
  }

  /// @inheritdoc IPositionManagerBase
  function setSelfAsUserPositionManagerWithSig(
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    try
      ISpoke(SPOKE).setUserPositionManagerWithSig({
        positionManager: address(this),
        user: user,
        approve: approve,
        nonce: nonce,
        deadline: deadline,
        signature: signature
      })
    {} catch {}
  }

  /// @inheritdoc IPositionManagerBase
  function permitReserve(
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external {
    address underlying = address(_getReserveUnderlying(reserveId));
    try
      IERC20Permit(underlying).permit({
        owner: onBehalfOf,
        spender: address(this),
        value: value,
        deadline: deadline,
        v: permitV,
        r: permitR,
        s: permitS
      })
    {} catch {}
  }

  /// @return The underlying asset for `reserveId` on the Spoke.
  function _getReserveUnderlying(uint256 reserveId) internal view returns (IERC20) {
    return IERC20(ISpoke(SPOKE).getReserve(reserveId).underlying);
  }
}
