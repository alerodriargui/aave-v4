// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';

type ConfigPermissions is uint8;

/// @title IPositionConfigPositionManager
/// @author Aave Labs
/// @notice Interface for position manager handling position configuration actions on behalf of an user.
interface IPositionConfigPositionManager is IPositionManagerBase {
  /// @notice Struct to hold the config permission values.
  /// @dev canSetUsingAsCollateral: Whether the caller can set using as collateral on behalf of the user.
  /// @dev canUpdateUserRiskPremium: Whether the caller can update user risk premium on behalf of the user.
  /// @dev canUpdateUserDynamicConfig: Whether the caller can update user dynamic config on behalf of the user.
  struct ConfigPermissionValues {
    bool canSetUsingAsCollateral;
    bool canUpdateUserRiskPremium;
    bool canUpdateUserDynamicConfig;
  }

  /// @notice Emitted when a global config permission is updated.
  event ConfigPermissionsUpdated(
    address indexed owner,
    address indexed caller,
    ConfigPermissions permissions
  );

  /// @notice Thrown when the caller of a function was not given persmission by the user.
  error CallerNotAllowed();

  /// @notice Sets the global permission for a caller.
  /// @param caller The address of the caller.
  /// @param permission The new permission status.
  function setGlobalPermission(address caller, bool permission) external;

  /// @notice Sets the using as collateral permission for a caller.
  /// @param caller The address of the caller.
  /// @param permission The new permission status.
  function setUsingAsCollateralPermission(address caller, bool permission) external;

  /// @notice Sets the user risk premium permission for a caller.
  /// @param caller The address of the caller.
  /// @param permission The new permission status.
  function setUserRiskPremiumPermission(address caller, bool permission) external;

  /// @notice Sets the user dynamic config permission for a caller.
  /// @param caller The address of the caller.
  /// @param permission The new permission status.
  function setUserDynamicConfigPermission(address caller, bool permission) external;

  /// @notice Renounces the global permission given by the owner.
  /// @param owner The address of the owner.
  function renounceGlobalPermission(address owner) external;

  /// @notice Renounces the using as collateral permission given by the owner.
  /// @param owner The address of the owner.
  function renounceUsingAsCollateralPermission(address owner) external;

  /// @notice Renounces the user risk premium permission given by the owner.
  /// @param owner The address of the owner.
  function renounceUserRiskPremiumPermission(address owner) external;

  /// @notice Renounces the user dynamic config permission given by the owner.
  /// @param owner The address of the owner.
  function renounceUserDynamicConfigPermission(address owner) external;

  /// @notice Sets the using as collateral status on behalf of a user for a specified reserve.
  /// @dev The Caller must have the permission to perform this action on behalf of the user.
  /// @param onBehalfOf The address of the user.
  /// @param reserveId The id of the reserve.
  /// @param usingAsCollateral The new using as collateral status.
  function setUsingAsCollateralOnBehalfOf(
    address onBehalfOf,
    uint256 reserveId,
    bool usingAsCollateral
  ) external;

  /// @notice Updates the user risk premium on behalf of a user.
  /// @dev The Caller must have the permission to perform this action on behalf of the user.
  /// @param onBehalfOf The address of the user.
  function updateUserRiskPremiumOnBehalfOf(address onBehalfOf) external;

  /// @notice Updates the user dynamic config on behalf of a user.
  /// @dev The Caller must have the permission to perform this action on behalf of the user.
  /// @param onBehalfOf The address of the user.
  function updateUserDynamicConfigOnBehalfOf(address onBehalfOf) external;

  /// @notice Returns the config permissions for a caller on behalf of a user.
  /// @param caller The address of the caller.
  /// @param onBehalfOf The address of the user.
  /// @return The ConfigPermissionValues for the caller on behalf of the user.
  function getConfigPermissions(
    address caller,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory);
}
