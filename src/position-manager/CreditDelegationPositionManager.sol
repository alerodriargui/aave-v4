// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SignatureChecker} from 'src/dependencies/openzeppelin/SignatureChecker.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {EIP712} from 'src/dependencies/solady/EIP712.sol';
import {NoncesKeyed} from 'src/utils/NoncesKeyed.sol';
import {EIP712Hash, EIP712Types} from 'src/position-manager/libraries/EIP712Hash.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {ICreditDelegationPositionManager} from 'src/position-manager/interfaces/ICreditDelegationPositionManager.sol';

/// @title CreditDelegationPositionManager
/// @author Aave Labs
/// @notice Position manager to handle credit delegation and borrow actions on behalf of users.
contract CreditDelegationPositionManager is
  ICreditDelegationPositionManager,
  PositionManagerBase,
  NoncesKeyed,
  EIP712
{
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @notice Mapping of credit delegations: owner => spender => reserveId => amount.
  mapping(address => mapping(address => mapping(uint256 => uint256))) private _creditDelegations;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  /// @inheritdoc ICreditDelegationPositionManager
  function approveCreditDelegation(address spender, uint256 reserveId, uint256 amount) external {
    _creditDelegations[msg.sender][spender][reserveId] = amount;
    emit CreditDelegation(msg.sender, spender, reserveId, amount);
  }

  /// @inheritdoc ICreditDelegationPositionManager
  function approveCreditDelegationWithSig(
    EIP712Types.CreditDelegation calldata params,
    bytes calldata signature
  ) external {
    require(block.timestamp <= params.deadline, InvalidSignature());
    address user = params.owner;
    bytes32 digest = _hashTypedData(params.hash());
    require(SignatureChecker.isValidSignatureNow(user, digest, signature), InvalidSignature());
    _useCheckedNonce(user, params.nonce);

    _creditDelegations[user][params.spender][params.reserveId] = params.amount;
    emit CreditDelegation(user, params.spender, params.reserveId, params.amount);
  }

  /// @inheritdoc ICreditDelegationPositionManager
  function borrowOnBehalfOf(
    uint256 reserveId,
    uint256 amount,
    address onBehalfOf
  ) external returns (uint256, uint256) {
    uint256 currentAllowance = _creditDelegations[onBehalfOf][msg.sender][reserveId];
    if (currentAllowance < amount) {
      revert InsufficientCreditDelegation();
    }
    _creditDelegations[onBehalfOf][msg.sender][reserveId] -= amount;

    IERC20 asset = _getReserveUnderlying(reserveId);
    (uint256 borrowedShares, uint256 borrowedAmount) = SPOKE.borrow(reserveId, amount, onBehalfOf);
    asset.safeTransfer(msg.sender, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc ICreditDelegationPositionManager
  function creditDelegationAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256) {
    return _creditDelegations[owner][spender][reserveId];
  }

  /// @inheritdoc ICreditDelegationPositionManager
  function CREDIT_DELEGATION_TYPEHASH() external pure returns (bytes32) {
    return EIP712Hash.CREDIT_DELEGATION_TYPEHASH;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('CreditDelegationPositionManager', '1');
  }
}
