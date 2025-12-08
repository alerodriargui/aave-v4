// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {IWithdrawPermitPositionManager} from 'src/position-manager/interfaces/IWithdrawPermitPositionManager.sol';

/// @title WithdrawPermitPositionManager
/// @author Aave Labs
/// @notice Position manager to handle withdraw permit actions on behalf of users.
contract WithdrawPermitPositionManager is
  IWithdrawPermitPositionManager,
  PositionManagerBase,
  NoncesKeyed,
  EIP712
{
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @notice Mapping of withdraw allowances: owner => spender => reserveId => amount.
  mapping(address => mapping(address => mapping(uint256 => uint256))) private _withdrawAllowances;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  /// @inheritdoc IWithdrawPermitPositionManager
  function approveWithdraw(address spender, uint256 reserveId, uint256 amount) external {
    _withdrawAllowances[msg.sender][spender][reserveId] = amount;
    emit WithdrawApproval(msg.sender, spender, reserveId, amount);
  }

  /// @inheritdoc IWithdrawPermitPositionManager
  function approveWithdrawWithSig(
    EIP712Types.WithdrawPermit calldata params,
    bytes calldata signature
  ) external {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address user = params.owner;
    bytes32 digest = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    _withdrawAllowances[user][params.spender][params.reserveId] = params.amount;
    emit WithdrawApproval(user, params.spender, params.reserveId, params.amount);
  }

  /// @inheritdoc IWithdrawPermitPositionManager
  function withdrawOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    uint256 currentAllowance = _withdrawAllowances[onBehalfOf][msg.sender][reserveId];
    if (currentAllowance < amount) {
      revert InsufficientWithdrawAllowance();
    }
    _withdrawAllowances[onBehalfOf][msg.sender][reserveId] -= amount;

    IERC20 asset = _getReserveUnderlying(reserveId);
    (uint256 withdrawnShares, uint256 withdrawnAmount) = SPOKE.withdraw(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc IWithdrawPermitPositionManager
  function withdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256) {
    return _withdrawAllowances[owner][spender][reserveId];
  }

  /// @inheritdoc IWithdrawPermitPositionManager
  function WITHDRAW_PERMIT_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.WITHDRAW_TYPEHASH;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('WithdrawPermitPositionManager', '1');
  }
}
