// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {SlotDerivation} from 'src/dependencies/openzeppelin/SlotDerivation.sol';
import {TransientSlot} from 'src/dependencies/openzeppelin/TransientSlot.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';
import {IAllowancePositionManager} from 'src/position-manager/interfaces/IAllowancePositionManager.sol';

/// @title AllowancePositionManager
/// @author Aave Labs
/// @notice Position manager to handle withdraw permit, credit delegation and borrow actions on behalf of users.
contract AllowancePositionManager is
  IAllowancePositionManager,
  PositionManagerBase,
  NoncesKeyed,
  EIP712
{
  using SafeERC20 for IERC20;
  using EIP712Hash for *;
  using MathUtils for uint256;
  using SlotDerivation for bytes32;
  using TransientSlot for *;

  /// @notice Mapping of withdraw allowances.
  mapping(address owner => mapping(address spender => mapping(uint256 reserveId => uint256 amount)))
    private _withdrawAllowances;

  /// @notice Slot for the temporary withdraw allowances.
  /// @dev keccak256('temporary.withdrawAllowances')
  bytes32 private constant _TEMPORARY_WITHDRAW_ALLOWANCES_SLOT =
    0x1c6a61279a13a86a789311ddf30aee38e2f4a9f6c4aad1ff4a2e75a4018e68c3;

  /// @notice Mapping of credit delegations.
  mapping(address owner => mapping(address spender => mapping(uint256 reserveId => uint256 amount)))
    private _creditDelegations;

  /// @notice Slot for the temporary credit delegations.
  /// @dev keccak256('temporary.creditDelegations')
  bytes32 private constant _TEMPORARY_CREDIT_DELEGATIONS_SLOT =
    0xcd470af8670f5baa744a0341af8a2e3f5d7ca086178908432a5cfaf39cb9299d;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  /// @inheritdoc IAllowancePositionManager
  function approveWithdraw(address spender, uint256 reserveId, uint256 amount) external {
    _updateWithdrawAllowance({
      owner: msg.sender,
      spender: spender,
      reserveId: reserveId,
      newAllowance: amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function approveWithdrawWithSig(
    EIP712Types.WithdrawPermit calldata params,
    bytes calldata signature
  ) external {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.owner, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.owner, params.nonce);

    _updateWithdrawAllowance({
      owner: params.owner,
      spender: params.spender,
      reserveId: params.reserveId,
      newAllowance: params.amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function temporaryApproveWithdraw(address spender, uint256 reserveId, uint256 amount) external {
    _temporaryWithdrawAllowancesSlot(msg.sender, spender, reserveId).tstore(amount);
  }

  /// @inheritdoc IAllowancePositionManager
  function delegateCredit(address spender, uint256 reserveId, uint256 amount) external {
    _updateCreditDelegation({
      owner: msg.sender,
      spender: spender,
      reserveId: reserveId,
      newCreditDelegation: amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function delegateCreditWithSig(
    EIP712Types.CreditDelegation calldata params,
    bytes calldata signature
  ) external {
    require(block.timestamp <= params.deadline, InvalidSignature());
    bytes32 digest = _hashTypedData(params.hash());
    require(
      SignatureChecker.isValidSignatureNow(params.owner, digest, signature),
      InvalidSignature()
    );
    _useCheckedNonce(params.owner, params.nonce);

    _updateCreditDelegation({
      owner: params.owner,
      spender: params.spender,
      reserveId: params.reserveId,
      newCreditDelegation: params.amount
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function temporaryDelegateCredit(address spender, uint256 reserveId, uint256 amount) external {
    _temporaryDelegateCreditsSlot(msg.sender, spender, reserveId).tstore(amount);
  }

  /// @inheritdoc IAllowancePositionManager
  function renounceWithdrawAllowance(address owner, uint256 reserveId) external {
    if (_withdrawAllowances[owner][msg.sender][reserveId] == 0) {
      return;
    }
    _updateWithdrawAllowance({
      owner: owner,
      spender: msg.sender,
      reserveId: reserveId,
      newAllowance: 0
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function renounceCreditDelegation(address owner, uint256 reserveId) external {
    if (_creditDelegations[owner][msg.sender][reserveId] == 0) {
      return;
    }
    _updateCreditDelegation({
      owner: owner,
      spender: msg.sender,
      reserveId: reserveId,
      newCreditDelegation: 0
    });
  }

  /// @inheritdoc IAllowancePositionManager
  function withdrawOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    _spendWithdrawAllowance({
      owner: onBehalfOf,
      spender: msg.sender,
      reserveId: reserveId,
      amount: amount
    });

    IERC20 asset = _getReserveUnderlying(reserveId);
    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpokeBase(SPOKE).withdraw(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc IAllowancePositionManager
  function borrowOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    _spendCreditDelegation({
      owner: onBehalfOf,
      spender: msg.sender,
      reserveId: reserveId,
      amount: amount
    });

    IERC20 asset = _getReserveUnderlying(reserveId);
    (uint256 borrowedShares, uint256 borrowedAmount) = ISpokeBase(SPOKE).borrow(
      reserveId,
      amount,
      onBehalfOf
    );
    asset.safeTransfer(msg.sender, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc IAllowancePositionManager
  function withdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256) {
    return _withdrawAllowances[owner][spender][reserveId];
  }

  /// @inheritdoc IAllowancePositionManager
  function creditDelegation(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256) {
    return _creditDelegations[owner][spender][reserveId];
  }

  /// @inheritdoc IAllowancePositionManager
  function DOMAIN_SEPARATOR() external view returns (bytes32) {
    return _domainSeparator();
  }

  /// @inheritdoc IAllowancePositionManager
  function WITHDRAW_PERMIT_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.WITHDRAW_PERMIT_TYPEHASH;
  }

  /// @inheritdoc IAllowancePositionManager
  function CREDIT_DELEGATION_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.CREDIT_DELEGATION_TYPEHASH;
  }

  /// @dev Temporary allowance takes precedence over stored allowance, and does not cumulate.
  function _spendWithdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId,
    uint256 amount
  ) internal {
    uint256 temporaryAllowance = _temporaryWithdrawAllowancesSlot(owner, spender, reserveId)
      .tload();
    if (temporaryAllowance > 0) {
      require(
        temporaryAllowance >= amount,
        InsufficientWithdrawAllowance(temporaryAllowance, amount)
      );
      _temporaryWithdrawAllowancesSlot(owner, spender, reserveId).tstore(
        temporaryAllowance.uncheckedSub(amount)
      );
    } else {
      uint256 allowance = _withdrawAllowances[owner][spender][reserveId];
      require(allowance >= amount, InsufficientWithdrawAllowance(allowance, amount));
      _withdrawAllowances[owner][spender][reserveId] = allowance.uncheckedSub(amount);
    }
  }

  /// @dev Temporary allowance takes precedence over stored allowance, and does not cumulate.
  function _spendCreditDelegation(
    address owner,
    address spender,
    uint256 reserveId,
    uint256 amount
  ) internal {
    uint256 temporaryAllowance = _temporaryDelegateCreditsSlot(owner, spender, reserveId).tload();
    if (temporaryAllowance > 0) {
      require(
        temporaryAllowance >= amount,
        InsufficientCreditDelegation(temporaryAllowance, amount)
      );
      _temporaryDelegateCreditsSlot(owner, spender, reserveId).tstore(
        temporaryAllowance.uncheckedSub(amount)
      );
    } else {
      uint256 allowance = _creditDelegations[owner][spender][reserveId];
      require(allowance >= amount, InsufficientCreditDelegation(allowance, amount));
      _creditDelegations[owner][spender][reserveId] = allowance.uncheckedSub(amount);
    }
  }

  function _updateWithdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId,
    uint256 newAllowance
  ) internal {
    _withdrawAllowances[owner][spender][reserveId] = newAllowance;
    emit WithdrawApproval(owner, spender, reserveId, newAllowance);
  }

  function _updateCreditDelegation(
    address owner,
    address spender,
    uint256 reserveId,
    uint256 newCreditDelegation
  ) internal {
    _creditDelegations[owner][spender][reserveId] = newCreditDelegation;
    emit CreditDelegation(owner, spender, reserveId, newCreditDelegation);
  }

  function _temporaryWithdrawAllowancesSlot(
    address owner,
    address spender,
    uint256 reserveId
  ) internal pure returns (TransientSlot.Uint256Slot) {
    return
      _TEMPORARY_WITHDRAW_ALLOWANCES_SLOT
        .deriveMapping(owner)
        .deriveMapping(spender)
        .deriveMapping(reserveId)
        .asUint256();
  }

  function _temporaryDelegateCreditsSlot(
    address owner,
    address spender,
    uint256 reserveId
  ) internal pure returns (TransientSlot.Uint256Slot) {
    return
      _TEMPORARY_CREDIT_DELEGATIONS_SLOT
        .deriveMapping(owner)
        .deriveMapping(spender)
        .deriveMapping(reserveId)
        .asUint256();
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('AllowancePositionManager', '1');
  }
}
