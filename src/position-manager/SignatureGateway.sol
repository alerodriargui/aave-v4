// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20Permit} from 'src/dependencies/openzeppelin/IERC20Permit.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';
import {BatchEIP712} from 'src/position-manager/libraries/BatchEIP712.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {GatewayBase} from 'src/position-manager/GatewayBase.sol';
import {IntentConsumer} from 'src/utils/IntentConsumer.sol';
import {Multicall} from 'src/utils/Multicall.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';
import {ISignatureTransfer} from 'lib/permit2/src/interfaces/ISignatureTransfer.sol';

/// @title SignatureGateway
/// @author Aave Labs
/// @notice Gateway to consume EIP-712 typed intents for spoke actions on behalf of a user.
/// @dev Contract must be an active & approved user position manager to execute spoke actions on user's behalf.
/// @dev Uses keyed-nonces where each key's namespace nonce is consumed sequentially. Intents bundled through
/// multicall can be executed independently in order of signed nonce & deadline; does not guarantee batch atomicity.
contract SignatureGateway is ISignatureGateway, GatewayBase, IntentConsumer, Multicall {
  using SafeERC20 for IERC20;
  using EIP712Hash for *;

  /// @inheritdoc ISignatureGateway
  string public constant SUPPLY_PERMIT2_WITNESS_TYPE_STRING =
    'Supply witness)Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)';

  /// @inheritdoc ISignatureGateway
  string public constant REPAY_PERMIT2_WITNESS_TYPE_STRING =
    'Repay witness)Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)';

  /// @inheritdoc ISignatureGateway
  bytes32 public constant SUPPLY_TYPEHASH = EIP712Hash.SUPPLY_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant WITHDRAW_TYPEHASH = EIP712Hash.WITHDRAW_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant BORROW_TYPEHASH = EIP712Hash.BORROW_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant REPAY_TYPEHASH = EIP712Hash.REPAY_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant SET_USING_AS_COLLATERAL_TYPEHASH =
    EIP712Hash.SET_USING_AS_COLLATERAL_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_RISK_PREMIUM_TYPEHASH =
    EIP712Hash.UPDATE_USER_RISK_PREMIUM_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  bytes32 public constant UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH =
    EIP712Hash.UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH;

  /// @inheritdoc ISignatureGateway
  address public immutable PERMIT2;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  /// @param permit2_ The address of the Permit2 contract.
  constructor(address initialOwner_, address permit2_) GatewayBase(initialOwner_) {
    require(permit2_ != address(0), InvalidAddress());
    PERMIT2 = permit2_;
  }

  /// @inheritdoc ISignatureGateway
  function supplyWithSig(
    Supply calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    underlying.safeTransferFrom(user, address(this), params.amount);
    underlying.forceApprove(spoke, params.amount);

    return ISpoke(spoke).supply(reserveId, params.amount, user);
  }

  /// @inheritdoc ISignatureGateway
  function withdrawWithSig(
    Withdraw calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    (uint256 withdrawnShares, uint256 withdrawnAmount) = ISpoke(spoke).withdraw(
      reserveId,
      params.amount,
      user
    );
    underlying.safeTransfer(user, withdrawnAmount);

    return (withdrawnShares, withdrawnAmount);
  }

  /// @inheritdoc ISignatureGateway
  function borrowWithSig(
    Borrow calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    (uint256 borrowedShares, uint256 borrowedAmount) = ISpoke(spoke).borrow(
      reserveId,
      params.amount,
      user
    );
    underlying.safeTransfer(user, borrowedAmount);

    return (borrowedShares, borrowedAmount);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithSig(
    Repay calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    address spoke = params.spoke;
    uint256 reserveId = params.reserveId;
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    IERC20 underlying = IERC20(_getReserveUnderlying(spoke, reserveId));
    uint256 repayAmount = MathUtils.min(
      params.amount,
      ISpoke(spoke).getUserTotalDebt(reserveId, user)
    );

    underlying.safeTransferFrom(user, address(this), repayAmount);
    underlying.forceApprove(spoke, repayAmount);

    return ISpoke(spoke).repay(reserveId, repayAmount, user);
  }

  /// @inheritdoc ISignatureGateway
  function setUsingAsCollateralWithSig(
    SetUsingAsCollateral calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    address user = params.onBehalfOf;
    _verifyAndConsumeIntent({
      signer: user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    ISpoke(params.spoke).setUsingAsCollateral(params.reserveId, params.useAsCollateral, user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserRiskPremiumWithSig(
    UpdateUserRiskPremium calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    ISpoke(params.spoke).updateUserRiskPremium(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function updateUserDynamicConfigWithSig(
    UpdateUserDynamicConfig calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) {
    _verifyAndConsumeIntent({
      signer: params.user,
      intentHash: params.hash(),
      nonce: params.nonce,
      deadline: params.deadline,
      signature: signature
    });

    ISpoke(params.spoke).updateUserDynamicConfig(params.user);
  }

  /// @inheritdoc ISignatureGateway
  function setSelfAsUserPositionManagerWithSig(
    address spoke,
    address user,
    bool approve,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external onlyRegisteredSpoke(spoke) {
    ISpoke.PositionManagerUpdate[] memory updates = new ISpoke.PositionManagerUpdate[](1);
    updates[0] = ISpoke.PositionManagerUpdate({positionManager: address(this), approve: approve});
    try
      ISpoke(spoke).setUserPositionManagersWithSig(
        ISpoke.SetUserPositionManagers({
          user: user,
          updates: updates,
          nonce: nonce,
          deadline: deadline
        }),
        signature
      )
    {} catch {}
  }

  /// @inheritdoc ISignatureGateway
  function permitReserve(
    address spoke,
    uint256 reserveId,
    address onBehalfOf,
    uint256 value,
    uint256 deadline,
    uint8 permitV,
    bytes32 permitR,
    bytes32 permitS
  ) external onlyRegisteredSpoke(spoke) {
    address underlying = _getReserveUnderlying(spoke, reserveId);
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

  /// @inheritdoc ISignatureGateway
  function supplyWithPermit2(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    Supply calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    _useCheckedNonce(params.onBehalfOf, params.nonce);

    ISignatureTransfer(PERMIT2).permitWitnessTransferFrom(
      permit,
      ISignatureTransfer.SignatureTransferDetails(address(this), params.amount),
      params.onBehalfOf,
      params.hash(),
      SUPPLY_PERMIT2_WITNESS_TYPE_STRING,
      signature
    );

    address underlying = _getReserveUnderlying(params.spoke, params.reserveId);
    IERC20(underlying).forceApprove(params.spoke, params.amount);

    return ISpoke(params.spoke).supply(params.reserveId, params.amount, params.onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function repayWithPermit2(
    ISignatureTransfer.PermitTransferFrom calldata permit,
    Repay calldata params,
    bytes calldata signature
  ) external onlyRegisteredSpoke(params.spoke) returns (uint256, uint256) {
    require(block.timestamp <= params.deadline, InvalidSignature());
    _useCheckedNonce(params.onBehalfOf, params.nonce);

    uint256 repayAmount = MathUtils.min(
      params.amount,
      ISpoke(params.spoke).getUserTotalDebt(params.reserveId, params.onBehalfOf)
    );

    ISignatureTransfer(PERMIT2).permitWitnessTransferFrom(
      permit,
      ISignatureTransfer.SignatureTransferDetails(address(this), repayAmount),
      params.onBehalfOf,
      params.hash(),
      REPAY_PERMIT2_WITNESS_TYPE_STRING,
      signature
    );

    address underlying = _getReserveUnderlying(params.spoke, params.reserveId);
    IERC20(underlying).forceApprove(params.spoke, repayAmount);

    return ISpoke(params.spoke).repay(params.reserveId, repayAmount, params.onBehalfOf);
  }

  /// @inheritdoc ISignatureGateway
  function executeBatchWithSig(
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline,
    bytes calldata signature
  ) external {
    uint256 len = actionTypes.length;
    require(len == actionData.length, LengthMismatch());
    require(len > 0 && len <= 10, InvalidBatchSize());

    bytes32 structHash = BatchEIP712.hashBatch(
      actionTypes,
      actionData,
      onBehalfOf,
      nonce,
      deadline
    );
    _verifyAndConsumeIntent({
      signer: onBehalfOf,
      intentHash: structHash,
      nonce: nonce,
      deadline: deadline,
      signature: signature
    });

    for (uint256 i = 0; i < len; i++) {
      _executeAction(actionTypes[i], actionData[i], onBehalfOf);
    }
  }

  /// @dev Execute a single action from the batch.
  /// @param actionType The action type enum value.
  /// @param actionData The ABI-encoded action struct.
  /// @param onBehalfOf The user on whose behalf the action is performed.
  function _executeAction(uint8 actionType, bytes memory actionData, address onBehalfOf) internal {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) {
      _executeSupplyAction(actionData, onBehalfOf);
    } else if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) {
      _executeWithdrawAction(actionData, onBehalfOf);
    } else if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) {
      _executeBorrowAction(actionData, onBehalfOf);
    } else if (actionType == uint8(ISignatureGateway.ActionType.Repay)) {
      _executeRepayAction(actionData, onBehalfOf);
    } else if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) {
      _executeSetUsingAsCollateralAction(actionData, onBehalfOf);
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) {
      _executeUpdateUserRiskPremiumAction(actionData, onBehalfOf);
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) {
      _executeUpdateUserDynamicConfigAction(actionData, onBehalfOf);
    } else {
      revert InvalidActionType();
    }
  }

  /// @dev Execute a supply action.
  function _executeSupplyAction(bytes memory actionData, address onBehalfOf) internal {
    ISignatureGateway.SupplyAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.SupplyAction)
    );
    _isSpokeValid(action.spoke);

    IERC20 underlying = IERC20(_getReserveUnderlying(action.spoke, action.reserveId));
    underlying.safeTransferFrom(onBehalfOf, address(this), action.amount);
    underlying.forceApprove(action.spoke, action.amount);

    ISpoke(action.spoke).supply(action.reserveId, action.amount, onBehalfOf);
  }

  /// @dev Execute a withdraw action.
  function _executeWithdrawAction(bytes memory actionData, address onBehalfOf) internal {
    ISignatureGateway.WithdrawAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.WithdrawAction)
    );
    _isSpokeValid(action.spoke);

    IERC20 underlying = IERC20(_getReserveUnderlying(action.spoke, action.reserveId));
    (, uint256 withdrawnAmount) = ISpoke(action.spoke).withdraw(
      action.reserveId,
      action.amount,
      onBehalfOf
    );
    underlying.safeTransfer(onBehalfOf, withdrawnAmount);
  }

  /// @dev Execute a borrow action.
  function _executeBorrowAction(bytes memory actionData, address onBehalfOf) internal {
    ISignatureGateway.BorrowAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.BorrowAction)
    );
    _isSpokeValid(action.spoke);

    IERC20 underlying = IERC20(_getReserveUnderlying(action.spoke, action.reserveId));
    (, uint256 borrowedAmount) = ISpoke(action.spoke).borrow(
      action.reserveId,
      action.amount,
      onBehalfOf
    );
    underlying.safeTransfer(onBehalfOf, borrowedAmount);
  }

  /// @dev Execute a repay action.
  function _executeRepayAction(bytes memory actionData, address onBehalfOf) internal {
    ISignatureGateway.RepayAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.RepayAction)
    );
    _isSpokeValid(action.spoke);

    IERC20 underlying = IERC20(_getReserveUnderlying(action.spoke, action.reserveId));
    uint256 repayAmount = MathUtils.min(
      action.amount,
      ISpoke(action.spoke).getUserTotalDebt(action.reserveId, onBehalfOf)
    );

    underlying.safeTransferFrom(onBehalfOf, address(this), repayAmount);
    underlying.forceApprove(action.spoke, repayAmount);

    ISpoke(action.spoke).repay(action.reserveId, repayAmount, onBehalfOf);
  }

  /// @dev Execute a setUsingAsCollateral action.
  function _executeSetUsingAsCollateralAction(
    bytes memory actionData,
    address onBehalfOf
  ) internal {
    ISignatureGateway.SetUsingAsCollateralAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.SetUsingAsCollateralAction)
    );
    _isSpokeValid(action.spoke);

    ISpoke(action.spoke).setUsingAsCollateral(action.reserveId, action.useAsCollateral, onBehalfOf);
  }

  /// @dev Execute an updateUserRiskPremium action.
  function _executeUpdateUserRiskPremiumAction(
    bytes memory actionData,
    address onBehalfOf
  ) internal {
    ISignatureGateway.UpdateUserRiskPremiumAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.UpdateUserRiskPremiumAction)
    );
    _isSpokeValid(action.spoke);

    ISpoke(action.spoke).updateUserRiskPremium(onBehalfOf);
  }

  /// @dev Execute an updateUserDynamicConfig action.
  function _executeUpdateUserDynamicConfigAction(
    bytes memory actionData,
    address onBehalfOf
  ) internal {
    ISignatureGateway.UpdateUserDynamicConfigAction memory action = abi.decode(
      actionData,
      (ISignatureGateway.UpdateUserDynamicConfigAction)
    );
    _isSpokeValid(action.spoke);

    ISpoke(action.spoke).updateUserDynamicConfig(onBehalfOf);
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('SignatureGateway', '1');
  }
}
