// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';
import {IAllowancePositionManager} from 'src/position-manager/interfaces/IAllowancePositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title AllowancePositionManager
/// @author Aave Labs
/// @notice Position manager to handle withdraw permit, credit delegation and borrow actions on behalf of users.
contract AllowancePositionManager is IAllowancePositionManager, PositionManagerBase {
  using SafeERC20 for IERC20;
  using MathUtils for uint256;
  using EIP712Hash for *;

  /// @dev Map of spoke and reserveId to owner to spender to withdraw allowance.
  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _withdrawAllowances;

  /// @dev Map of spoke and reserveId to owner to spender to credit delegation.
  mapping(address spoke => mapping(uint256 reserveId => mapping(address owner => mapping(address spender => uint256 amount))))
    private _creditDelegations;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc IAllowancePositionManager
  function approveWithdraw(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _updateWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender,
      newAllowance: amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function approveWithdrawWithSig(
    WithdrawPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.owner,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    _updateWithdrawAllowance({
      spoke: params.spoke,
      reserveId: params.reserveId,
      owner: params.owner,
      spender: params.spender,
      newAllowance: params.amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function delegateCredit(
    address spoke,
    uint256 reserveId,
    address spender,
    uint256 amount
  ) external onlyRegisteredSpoke(spoke) {
    _updateCreditDelegation({
      spoke: spoke,
      reserveId: reserveId,
      owner: msg.sender,
      spender: spender,
      newCreditDelegation: amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function delegateCreditWithSig(
    CreditDelegationPermit calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.owner,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    _updateCreditDelegation({
      spoke: params.spoke,
      reserveId: params.reserveId,
      owner: params.owner,
      spender: params.spender,
      newCreditDelegation: params.amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function renounceWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    if (_withdrawAllowances[spoke][reserveId][owner][msg.sender] == 0) {
      return;
    }
    _updateWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: msg.sender,
      newAllowance: 0
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function renounceCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    if (_creditDelegations[spoke][reserveId][owner][msg.sender] == 0) {
      return;
    }
    _updateCreditDelegation({
      spoke: spoke,
      reserveId: reserveId,
      owner: owner,
      spender: msg.sender,
      newCreditDelegation: 0
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function withdrawOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    IERC20 asset = IERC20(_getReserveUnderlying(spoke, reserveId));
    _spendWithdrawAllowance({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpokeBase(spoke).withdraw(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc IAllowancePositionManager
  function borrowOnBehalfOf(
    address spoke,
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) returns (uint256, uint256) {
    IERC20 asset = IERC20(_getReserveUnderlying(spoke, reserveId));
    _spendCreditDelegation({
      spoke: spoke,
      reserveId: reserveId,
      owner: onBehalfOf,
      spender: msg.sender,
      amount: amount
    });

    (uint256 borrowedShares, uint256 borrowedAmount) = ISpokeBase(spoke).borrow(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc IAllowancePositionManager
  function withdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return _withdrawAllowances[spoke][reserveId][owner][spender];
  }

  /// @inheritdoc IAllowancePositionManager
  function creditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender
  ) external view returns (uint256) {
    return _creditDelegations[spoke][reserveId][owner][spender];
  }

  /// @inheritdoc IAllowancePositionManager
  function WITHDRAW_PERMIT_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.WITHDRAW_PERMIT_TYPEHASH;
  }

  /// @inheritdoc IAllowancePositionManager
  function CREDIT_DELEGATION_PERMIT_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.CREDIT_DELEGATION_PERMIT_TYPEHASH;
  }

  function _updateWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 newAllowance
  ) internal {
    _withdrawAllowances[spoke][reserveId][owner][spender] = newAllowance;
    emit WithdrawApproval(spoke, reserveId, owner, spender, newAllowance);
  }

  function _updateCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 newCreditDelegation
  ) internal {
    _creditDelegations[spoke][reserveId][owner][spender] = newCreditDelegation;
    emit CreditDelegation(spoke, reserveId, owner, spender, newCreditDelegation);
  }

  function _spendWithdrawAllowance(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    uint256 currentAllowance = _withdrawAllowances[spoke][reserveId][owner][spender];
    require(currentAllowance >= amount, InsufficientWithdrawAllowance(currentAllowance, amount));
    if (currentAllowance != type(uint256).max) {
      _withdrawAllowances[spoke][reserveId][owner][spender] = currentAllowance.uncheckedSub(amount);
    }
  }

  function _spendCreditDelegation(
    address spoke,
    uint256 reserveId,
    address owner,
    address spender,
    uint256 amount
  ) internal {
    uint256 currentAllowance = _creditDelegations[spoke][reserveId][owner][spender];
    require(currentAllowance >= amount, InsufficientCreditDelegation(currentAllowance, amount));
    if (currentAllowance != type(uint256).max) {
      _creditDelegations[spoke][reserveId][owner][spender] = currentAllowance.uncheckedSub(amount);
    }
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('AllowancePositionManager', '1');
  }
}
