// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';
import {ISupplyRepayPositionManager} from 'src/position-manager/interfaces/ISupplyRepayPositionManager.sol';

/// @title SupplyRepayPositionManager
/// @author Aave Labs
/// @notice Position manager to handle supply and repay actions on behalf of users.
contract SupplyRepayPositionManager is ISupplyRepayPositionManager, PositionManagerBase {
  using SafeERC20 for IERC20;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  /// @inheritdoc ISupplyRepayPositionManager
  function supplyOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    IERC20 asset = _getReserveUnderlying(reserveId);
    asset.safeTransferFrom(msg.sender, address(this), amount);
    asset.forceApprove(SPOKE, amount);
    return ISpokeBase(SPOKE).supply(reserveId, amount, onBehalfOf);
  }

  /// @inheritdoc ISupplyRepayPositionManager
  function repayOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    IERC20 asset = _getReserveUnderlying(reserveId);

    uint256 userTotalDebt = ISpokeBase(SPOKE).getUserTotalDebt(reserveId, onBehalfOf);
    uint256 repayAmount = amount > userTotalDebt ? userTotalDebt : amount;

    asset.safeTransferFrom(msg.sender, address(this), repayAmount);
    asset.forceApprove(SPOKE, repayAmount);
    return ISpokeBase(SPOKE).repay(reserveId, repayAmount, onBehalfOf);
  }
}
