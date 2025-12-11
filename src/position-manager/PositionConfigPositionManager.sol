// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {ConfigPermissionsMap} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {IPositionConfigPositionManager, ConfigPermissions} from 'src/position-manager/interfaces/IPositionConfigPositionManager.sol';

/// @title PositionConfigPositionManager
/// @author Aave Labs
/// @notice Position manager to handle position configuration actions on behalf of users.
contract PositionConfigPositionManager is IPositionConfigPositionManager, PositionManagerBase {
  using ConfigPermissionsMap for ConfigPermissions;

  mapping(address owner => mapping(address caller => ConfigPermissions)) private _configPermissions;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  /// @inheritdoc IPositionConfigPositionManager
  function setGlobalPermission(address caller, bool permission) external {
    _configPermissions[msg.sender][caller] = _configPermissions[msg.sender][caller]
      .setFullPermissions(permission);

    emit GlobalConfigPermissionUpdated(msg.sender, caller, permission);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUsingAsCollateralPermission(address caller, bool permission) external {
    _configPermissions[msg.sender][caller] = _configPermissions[msg.sender][caller]
      .setCanSetUsingAsCollateral(permission);

    emit SetUsingAsCollateralPermissionUpdated(msg.sender, caller, permission);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUserRiskPremiumPermission(address caller, bool permission) external {
    _configPermissions[msg.sender][caller] = _configPermissions[msg.sender][caller]
      .setCanUpdateUserRiskPremium(permission);

    emit UserRiskPremiumPermissionUpdated(msg.sender, caller, permission);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUserDynamicConfigPermission(address caller, bool permission) external {
    _configPermissions[msg.sender][caller] = _configPermissions[msg.sender][caller]
      .setCanUpdateUserDynamicConfig(permission);

    emit UserDynamicConfigPermissionUpdated(msg.sender, caller, permission);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUsingAsCollateralOnBehalfOf(
    address onBehalfOf,
    uint256 reserveId,
    bool usingAsCollateral
  ) external {
    require(
      _configPermissions[onBehalfOf][msg.sender].canSetUsingAsCollateral(),
      CallerNotAllowed()
    );

    ISpoke(SPOKE).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function updateUserRiskPremiumOnBehalfOf(address onBehalfOf) external {
    require(
      _configPermissions[onBehalfOf][msg.sender].canUpdateUserRiskPremium(),
      CallerNotAllowed()
    );

    ISpoke(SPOKE).updateUserRiskPremium(onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function updateUserDynamicConfigOnBehalfOf(address onBehalfOf) external {
    require(
      _configPermissions[onBehalfOf][msg.sender].canUpdateUserDynamicConfig(),
      CallerNotAllowed()
    );

    ISpoke(SPOKE).updateUserDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function getConfigPermissions(
    address caller,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory) {
    ConfigPermissions permissions = _configPermissions[onBehalfOf][caller];
    return
      ConfigPermissionValues({
        canSetUsingAsCollateral: permissions.canSetUsingAsCollateral(),
        canUpdateUserRiskPremium: permissions.canUpdateUserRiskPremium(),
        canUpdateUserDynamicConfig: permissions.canUpdateUserDynamicConfig()
      });
  }
}
