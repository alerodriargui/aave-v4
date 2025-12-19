// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {INoncesKeyed} from 'src/interfaces/INoncesKeyed.sol';
import {EIP712Types} from 'src/libraries/types/EIP712Types.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

/// @title ISignatureGateway
/// @author Aave Labs
/// @notice Minimal interface for protocol actions involving signed intents.
interface ISignatureGateway is INoncesKeyed, IPositionManagerBase {
  /// @notice Facilitates `supply` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Supplied assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured supply parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares supplied.
  /// @return The amount of assets supplied.
  function supplyWithSig(
    EIP712Types.Supply calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `withdraw` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Providing an amount exceeding the user's current withdrawable balance indicates a request for a maximum withdrawal.
  /// @dev Withdrawn assets are pushed to `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured withdraw parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares withdrawn.
  /// @return The amount of assets withdrawn.
  function withdrawWithSig(
    EIP712Types.Withdraw calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `borrow` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Borrowed assets are pushed to `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured borrow parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares borrowed.
  /// @return The amount of assets borrowed.
  function borrowWithSig(
    EIP712Types.Borrow calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `repay` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Repay assets are pulled from `onBehalfOf`, prior approval to this gateway is required.
  /// @dev Providing an amount greater than the user's current debt indicates a request to repay the maximum possible amount.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured repay parameters.
  /// @param signature The signed bytes for the intent.
  /// @return The amount of shares repaid.
  /// @return The amount of assets repaid.
  function repayWithSig(
    EIP712Types.Repay calldata params,
    bytes calldata signature
  ) external returns (uint256, uint256);

  /// @notice Facilitates `setUsingAsCollateral` action on the specified registered `spoke` with a typed signature from `onBehalfOf`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured setUsingAsCollateral parameters.
  /// @param signature The signed bytes for the intent.
  function setUsingAsCollateralWithSig(
    EIP712Types.SetUsingAsCollateral calldata params,
    bytes calldata signature
  ) external;

  /// @notice Facilitates `updateUserRiskPremium` action on the specified registered `spoke` with a typed signature from `user`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured updateUserRiskPremium parameters.
  /// @param signature The signed bytes for the intent.
  function updateUserRiskPremiumWithSig(
    EIP712Types.UpdateUserRiskPremium calldata params,
    bytes calldata signature
  ) external;

  /// @notice Facilitates `updateUserDynamicConfig` action on the specified registered `spoke` with a typed signature from `user`.
  /// @dev Uses keyed-nonces where for each key's namespace nonce is consumed sequentially.
  /// @param params The structured updateUserDynamicConfig parameters.
  /// @param signature The signed bytes for the intent.
  function updateUserDynamicConfigWithSig(
    EIP712Types.UpdateUserDynamicConfig calldata params,
    bytes calldata signature
  ) external;

  /// @notice Returns the EIP712 domain separator.
  function DOMAIN_SEPARATOR() external view returns (bytes32);

  /// @notice Returns the type hash for the Supply intent.
  function SUPPLY_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the Withdraw intent.
  function WITHDRAW_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the Borrow intent.
  function BORROW_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the Repay intent.
  function REPAY_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the SetUsingAsCollateral intent.
  function SET_USING_AS_COLLATERAL_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the UpdateUserRiskPremium intent.
  function UPDATE_USER_RISK_PREMIUM_TYPEHASH() external view returns (bytes32);

  /// @notice Returns the type hash for the UpdateUserDynamicConfig intent.
  function UPDATE_USER_DYNAMIC_CONFIG_TYPEHASH() external view returns (bytes32);
}
