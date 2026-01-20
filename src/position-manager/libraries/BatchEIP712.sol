// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {ISignatureGateway} from 'src/position-manager/interfaces/ISignatureGateway.sol';

/// @title BatchEIP712 library
/// @author Aave Labs
/// @notice Helper methods to construct dynamic EIP-712 type strings and hash batch actions.
/// @dev Constructs type strings at runtime to maintain full wallet UX visibility for batch signing.
library BatchEIP712 {
  string internal constant SUPPLY_ACTION_NAME = 'SupplyAction';
  string internal constant WITHDRAW_ACTION_NAME = 'WithdrawAction';
  string internal constant BORROW_ACTION_NAME = 'BorrowAction';
  string internal constant REPAY_ACTION_NAME = 'RepayAction';
  string internal constant SET_USING_AS_COLLATERAL_ACTION_NAME = 'SetUsingAsCollateralAction';
  string internal constant UPDATE_USER_RISK_PREMIUM_ACTION_NAME = 'UpdateUserRiskPremiumAction';
  string internal constant UPDATE_USER_DYNAMIC_CONFIG_ACTION_NAME = 'UpdateUserDynamicConfigAction';

  string internal constant BORROW_ACTION_DEF =
    'BorrowAction(address spoke,uint256 reserveId,uint256 amount)';
  string internal constant REPAY_ACTION_DEF =
    'RepayAction(address spoke,uint256 reserveId,uint256 amount)';
  string internal constant SET_USING_AS_COLLATERAL_ACTION_DEF =
    'SetUsingAsCollateralAction(address spoke,uint256 reserveId,bool useAsCollateral)';
  string internal constant SUPPLY_ACTION_DEF =
    'SupplyAction(address spoke,uint256 reserveId,uint256 amount)';
  string internal constant UPDATE_USER_DYNAMIC_CONFIG_ACTION_DEF =
    'UpdateUserDynamicConfigAction(address spoke)';
  string internal constant UPDATE_USER_RISK_PREMIUM_ACTION_DEF =
    'UpdateUserRiskPremiumAction(address spoke)';
  string internal constant WITHDRAW_ACTION_DEF =
    'WithdrawAction(address spoke,uint256 reserveId,uint256 amount)';

  bytes32 internal constant SUPPLY_ACTION_TYPEHASH =
    // keccak256('SupplyAction(address spoke,uint256 reserveId,uint256 amount)')
    0x92108fb6c1c54e895857cadeb15a1d0ff251d05ab5bc45c397f7f0bf4513524f;

  bytes32 internal constant WITHDRAW_ACTION_TYPEHASH =
    // keccak256('WithdrawAction(address spoke,uint256 reserveId,uint256 amount)')
    0x9886e55b7e2df773f3c842b4432b6e809e8669053f302bffdacc143660738090;

  bytes32 internal constant BORROW_ACTION_TYPEHASH =
    // keccak256('BorrowAction(address spoke,uint256 reserveId,uint256 amount)')
    0x2d06ff6c841f7e36ccc14b960e3f08ce8e6eb41ab93b31281ffa7ad44e21026c;

  bytes32 internal constant REPAY_ACTION_TYPEHASH =
    // keccak256('RepayAction(address spoke,uint256 reserveId,uint256 amount)')
    0xd0bfcdb753a3de34964385d0931b97edfc843abb115302d37b474e15a31220e4;

  bytes32 internal constant SET_USING_AS_COLLATERAL_ACTION_TYPEHASH =
    // keccak256('SetUsingAsCollateralAction(address spoke,uint256 reserveId,bool useAsCollateral)')
    0x274cee27fcc6e1e5383183a5d15ceaba083b45ceb85fd75d497dc482b444ff89;

  bytes32 internal constant UPDATE_USER_RISK_PREMIUM_ACTION_TYPEHASH =
    // keccak256('UpdateUserRiskPremiumAction(address spoke)')
    0x3d45bb6df468588f10dd8ff3cb2c53086fc7d49dc451b275b868a3c2b32e50d7;

  bytes32 internal constant UPDATE_USER_DYNAMIC_CONFIG_ACTION_TYPEHASH =
    // keccak256('UpdateUserDynamicConfigAction(address spoke)')
    0x8548aa46ece028df12b6ecd855470cbc563c7599931c9c156ae140206e8853ca;

  bytes internal constant ACTION_FIELD_PREFIX = ' action';
  bytes internal constant FIELD_SEPARATOR = ',';

  bytes internal constant BATCH_PREFIX = 'Batch(';
  bytes internal constant BATCH_SUFFIX = 'address onBehalfOf,uint256 nonce,uint256 deadline)';

  /// @notice Build the batch type hash from an array of action types.
  /// @dev Constructs the type string dynamically and returns its keccak256 hash.
  /// @param actionTypes Array of action type enum values.
  /// @return The keccak256 hash of the constructed type string.
  function buildBatchTypeHash(uint8[] memory actionTypes) internal pure returns (bytes32) {
    return keccak256(bytes(buildBatchTypeString(actionTypes)));
  }

  /// @notice Build the full batch type string from an array of action types.
  /// @dev The type string format is:
  ///      Batch({ActionType} action0,{ActionType} action1,...,address onBehalfOf,uint256 nonce,uint256 deadline){TypeDefs}
  ///      where {TypeDefs} are the nested type definitions in alphabetical order.
  /// @param actionTypes Array of action type enum values.
  /// @return The constructed type string.
  function buildBatchTypeString(uint8[] memory actionTypes) internal pure returns (string memory) {
    uint256 len = actionTypes.length;

    // Track which action types are used (bitmap for deduplication)
    uint8 usedTypes = 0;

    // Build the Batch(...) part
    bytes memory batchPart = BATCH_PREFIX;

    for (uint256 i = 0; i < len; i++) {
      uint8 actionType = actionTypes[i];
      usedTypes |= uint8(1 << actionType);

      // Append "{ActionTypeName} action{i},"
      batchPart = bytes.concat(
        batchPart,
        bytes(_getActionTypeName(actionType)),
        ACTION_FIELD_PREFIX,
        bytes(_uintToString(i)),
        FIELD_SEPARATOR
      );
    }

    // Append the fixed suffix
    batchPart = bytes.concat(batchPart, BATCH_SUFFIX);

    // Append type definitions in alphabetical order
    // Order: Borrow < Repay < SetUsingAsCollateral < Supply < UpdateUserDynamicConfig < UpdateUserRiskPremium < Withdraw
    bytes memory typeDefs = '';

    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Borrow)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(BORROW_ACTION_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Repay)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(REPAY_ACTION_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(SET_USING_AS_COLLATERAL_ACTION_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Supply)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(SUPPLY_ACTION_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(UPDATE_USER_DYNAMIC_CONFIG_ACTION_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(UPDATE_USER_RISK_PREMIUM_ACTION_DEF));
    }
    if (usedTypes & (1 << uint8(ISignatureGateway.ActionType.Withdraw)) != 0) {
      typeDefs = bytes.concat(typeDefs, bytes(WITHDRAW_ACTION_DEF));
    }

    return string(bytes.concat(batchPart, typeDefs));
  }

  /// @notice Hash a specific action based on its type.
  /// @param actionType The action type enum value.
  /// @param actionData The ABI-encoded action struct.
  /// @return The struct hash of the action.
  function hashAction(uint8 actionType, bytes memory actionData) internal pure returns (bytes32) {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) {
      ISignatureGateway.SupplyAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.SupplyAction)
      );
      return
        keccak256(
          abi.encode(SUPPLY_ACTION_TYPEHASH, action.spoke, action.reserveId, action.amount)
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) {
      ISignatureGateway.WithdrawAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.WithdrawAction)
      );
      return
        keccak256(
          abi.encode(WITHDRAW_ACTION_TYPEHASH, action.spoke, action.reserveId, action.amount)
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) {
      ISignatureGateway.BorrowAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.BorrowAction)
      );
      return
        keccak256(
          abi.encode(BORROW_ACTION_TYPEHASH, action.spoke, action.reserveId, action.amount)
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.Repay)) {
      ISignatureGateway.RepayAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.RepayAction)
      );
      return
        keccak256(abi.encode(REPAY_ACTION_TYPEHASH, action.spoke, action.reserveId, action.amount));
    } else if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) {
      ISignatureGateway.SetUsingAsCollateralAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.SetUsingAsCollateralAction)
      );
      return
        keccak256(
          abi.encode(
            SET_USING_AS_COLLATERAL_ACTION_TYPEHASH,
            action.spoke,
            action.reserveId,
            action.useAsCollateral
          )
        );
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) {
      ISignatureGateway.UpdateUserRiskPremiumAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.UpdateUserRiskPremiumAction)
      );
      return keccak256(abi.encode(UPDATE_USER_RISK_PREMIUM_ACTION_TYPEHASH, action.spoke));
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) {
      ISignatureGateway.UpdateUserDynamicConfigAction memory action = abi.decode(
        actionData,
        (ISignatureGateway.UpdateUserDynamicConfigAction)
      );
      return keccak256(abi.encode(UPDATE_USER_DYNAMIC_CONFIG_ACTION_TYPEHASH, action.spoke));
    } else {
      revert('BatchEIP712: invalid action type');
    }
  }

  /// @notice Compute the full batch struct hash.
  /// @dev Per EIP-712, struct hash = keccak256(abi.encode(typeHash, member1, member2, ...))
  ///      For nested structs, each member is the hashStruct of that nested struct.
  /// @param actionTypes Array of action type enum values.
  /// @param actionData Array of ABI-encoded action structs.
  /// @param onBehalfOf The user on whose behalf all actions are performed.
  /// @param nonce The nonce for replay protection.
  /// @param deadline The deadline for the batch.
  /// @return The struct hash of the batch.
  function hashBatch(
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) internal pure returns (bytes32) {
    bytes32 typeHash = buildBatchTypeHash(actionTypes);

    // Build the encoding dynamically since number of action fields varies
    // Per EIP-712: each nested struct field is encoded as hashStruct(field)
    bytes memory encoded = abi.encode(typeHash);

    uint256 len = actionTypes.length;
    for (uint256 i = 0; i < len; i++) {
      encoded = bytes.concat(encoded, abi.encode(hashAction(actionTypes[i], actionData[i])));
    }

    // Append the fixed fields
    encoded = bytes.concat(encoded, abi.encode(onBehalfOf, nonce, deadline));

    return keccak256(encoded);
  }

  /// @notice Get the action type name string for a given action type.
  /// @param actionType The action type enum value.
  /// @return The action type name string.
  function _getActionTypeName(uint8 actionType) private pure returns (string memory) {
    if (actionType == uint8(ISignatureGateway.ActionType.Supply)) {
      return SUPPLY_ACTION_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.Withdraw)) {
      return WITHDRAW_ACTION_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.Borrow)) {
      return BORROW_ACTION_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.Repay)) {
      return REPAY_ACTION_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.SetUsingAsCollateral)) {
      return SET_USING_AS_COLLATERAL_ACTION_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium)) {
      return UPDATE_USER_RISK_PREMIUM_ACTION_NAME;
    } else if (actionType == uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig)) {
      return UPDATE_USER_DYNAMIC_CONFIG_ACTION_NAME;
    } else {
      revert('BatchEIP712: invalid action type');
    }
  }

  /// @notice Convert a uint256 to its string representation.
  /// @dev Only handles small numbers (0-9) for action indices.
  /// @param value The value to convert.
  /// @return The string representation.
  function _uintToString(uint256 value) private pure returns (string memory) {
    if (value == 0) return '0';
    if (value == 1) return '1';
    if (value == 2) return '2';
    if (value == 3) return '3';
    if (value == 4) return '4';
    if (value == 5) return '5';
    if (value == 6) return '6';
    if (value == 7) return '7';
    if (value == 8) return '8';
    if (value == 9) return '9';

    // For values >= 10, build the string
    bytes memory buffer;
    while (value > 0) {
      buffer = bytes.concat(bytes1(uint8(48 + (value % 10))), buffer);
      value /= 10;
    }
    return string(buffer);
  }
}
