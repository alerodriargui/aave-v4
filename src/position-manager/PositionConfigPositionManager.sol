// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ConfigPermissionsMap} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionConfigPositionManager, ConfigPermissions} from 'src/position-manager/interfaces/IPositionConfigPositionManager.sol';

/// @title PositionConfigPositionManager
/// @author Aave Labs
/// @notice Position manager to handle position configuration actions on behalf of users.
contract PositionConfigPositionManager is IPositionConfigPositionManager, PositionManagerBase {
  using ConfigPermissionsMap for ConfigPermissions;

  mapping(address owner => mapping(address caller => ConfigPermissions)) private _config;

  /// @dev Constructor.
  /// @param spoke_ The address of the spoke contract.
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  /// @inheritdoc IPositionConfigPositionManager
  function setGlobalPermission(address caller, bool permission) external {
    ConfigPermissions oldPermissions = _config[msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setFullPermissions(permission);
    _config[msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUsingAsCollateralPermission(address caller, bool permission) external {
    ConfigPermissions oldPermissions = _config[msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(permission);
    _config[msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUserRiskPremiumPermission(address caller, bool permission) external {
    ConfigPermissions oldPermissions = _config[msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(permission);
    _config[msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUserDynamicConfigPermission(address caller, bool permission) external {
    ConfigPermissions oldPermissions = _config[msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(permission);
    _config[msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceGlobalPermission(address owner) external {
    ConfigPermissions oldPermissions = _config[owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setFullPermissions(false);
    _config[owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceUsingAsCollateralPermission(address owner) external {
    ConfigPermissions oldPermissions = _config[owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(false);
    _config[owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceUserRiskPremiumPermission(address owner) external {
    ConfigPermissions oldPermissions = _config[owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(false);
    _config[owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceUserDynamicConfigPermission(address owner) external {
    ConfigPermissions oldPermissions = _config[owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(false);
    _config[owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUsingAsCollateralOnBehalfOf(
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external {
    require(_config[onBehalfOf][msg.sender].canSetUsingAsCollateral(), CallerNotAllowed());

    ISpoke(SPOKE).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function updateUserRiskPremiumOnBehalfOf(address onBehalfOf) external {
    require(_config[onBehalfOf][msg.sender].canUpdateUserRiskPremium(), CallerNotAllowed());

    ISpoke(SPOKE).updateUserRiskPremium(onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function updateUserDynamicConfigOnBehalfOf(address onBehalfOf) external {
    require(_config[onBehalfOf][msg.sender].canUpdateUserDynamicConfig(), CallerNotAllowed());

    ISpoke(SPOKE).updateUserDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function getConfigPermissions(
    address caller,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory) {
    ConfigPermissions permissions = _config[onBehalfOf][caller];
    return
      ConfigPermissionValues({
        canSetUsingAsCollateral: permissions.canSetUsingAsCollateral(),
        canUpdateUserRiskPremium: permissions.canUpdateUserRiskPremium(),
        canUpdateUserDynamicConfig: permissions.canUpdateUserDynamicConfig()
      });
  }
}
