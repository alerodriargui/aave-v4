// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ConfigPermissionsMap} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {
  IPositionConfigPositionManager,
  ConfigPermissions
} from 'src/position-manager/interfaces/IPositionConfigPositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title PositionConfigPositionManager
/// @author Aave Labs
/// @notice Position manager to handle position configuration actions on behalf of users.
contract PositionConfigPositionManager is IPositionConfigPositionManager, PositionManagerBase {
  using ConfigPermissionsMap for ConfigPermissions;

  mapping(address spoke => mapping(address owner => mapping(address caller => ConfigPermissions)))
    private _config;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial owner.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc IPositionConfigPositionManager
  function setGlobalPermission(
    address spoke,
    address caller,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setFullPermissions(permission);
    _config[spoke][msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setCanUpdateUsingAsCollateralPermission(
    address spoke,
    address caller,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(permission);
    _config[spoke][msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address caller,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(permission);
    _config[spoke][msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address caller,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][msg.sender][caller];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(permission);
    _config[spoke][msg.sender][caller] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, caller, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceGlobalPermission(
    address spoke,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setFullPermissions(false);
    _config[spoke][owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceCanUpdateUsingAsCollateralPermission(
    address spoke,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(false);
    _config[spoke][owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceCanUpdateUserRiskPremiumPermission(
    address spoke,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(false);
    _config[spoke][owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function renounceCanUpdateUserDynamicConfigPermission(
    address spoke,
    address owner
  ) external onlyRegisteredSpoke(spoke) {
    ConfigPermissions oldPermissions = _config[spoke][owner][msg.sender];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(false);
    _config[spoke][owner][msg.sender] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, owner, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IPositionConfigPositionManager
  function setUsingAsCollateralOnBehalfOf(
    address spoke,
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(_config[spoke][onBehalfOf][msg.sender].canSetUsingAsCollateral(), CallerNotAllowed());

    ISpoke(spoke).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function updateUserRiskPremiumOnBehalfOf(
    address spoke,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(_config[spoke][onBehalfOf][msg.sender].canUpdateUserRiskPremium(), CallerNotAllowed());

    ISpoke(spoke).updateUserRiskPremium(onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function updateUserDynamicConfigOnBehalfOf(
    address spoke,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _config[spoke][onBehalfOf][msg.sender].canUpdateUserDynamicConfig(),
      CallerNotAllowed()
    );

    ISpoke(spoke).updateUserDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc IPositionConfigPositionManager
  function getConfigPermissions(
    address spoke,
    address caller,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory) {
    ConfigPermissions permissions = _config[spoke][onBehalfOf][caller];
    return
      ConfigPermissionValues({
        canSetUsingAsCollateral: permissions.canSetUsingAsCollateral(),
        canUpdateUserRiskPremium: permissions.canUpdateUserRiskPremium(),
        canUpdateUserDynamicConfig: permissions.canUpdateUserDynamicConfig()
      });
  }

  function _isMulticallAllowed() internal pure override returns (bool) {
    return true;
  }

  function _isSpokeRegistryActive() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('PositionConfigPositionManager', '1');
  }
}
