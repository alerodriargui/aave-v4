// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ConfigPermissionsMap} from 'src/position-manager/libraries/ConfigPermissionsMap.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {
  IConfigPositionManager,
  ConfigPermissions
} from 'src/position-manager/interfaces/IConfigPositionManager.sol';
import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

/// @title ConfigPositionManager
/// @author Aave Labs
/// @notice Position manager to handle position configuration actions on behalf of users.
contract ConfigPositionManager is IConfigPositionManager, PositionManagerBase {
  using ConfigPermissionsMap for ConfigPermissions;

  /// @dev Map of config key to permissions.
  /// @dev The key is the keccak256 hash of abi.encode(spoke, delegator, delegatee).
  mapping(bytes32 key => ConfigPermissions value) private _config;

  /// @dev Constructor.
  /// @param initialOwner_ The address of the initial delegator.
  constructor(address initialOwner_) PositionManagerBase(initialOwner_) {}

  /// @inheritdoc IConfigPositionManager
  function setGlobalPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: msg.sender, delegatee: delegatee});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setFullPermissions(permission);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, delegatee, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUsingAsCollateralPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: msg.sender, delegatee: delegatee});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(permission);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, delegatee, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: msg.sender, delegatee: delegatee});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(permission);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, delegatee, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function setCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegatee,
    bool permission
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: msg.sender, delegatee: delegatee});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(permission);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, msg.sender, delegatee, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function renounceGlobalPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: delegator, delegatee: msg.sender});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setFullPermissions(false);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, delegator, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function renounceCanUpdateUsingAsCollateralPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: delegator, delegatee: msg.sender});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setCanSetUsingAsCollateral(false);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, delegator, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function renounceCanUpdateUserRiskPremiumPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: delegator, delegatee: msg.sender});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserRiskPremium(false);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, delegator, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function renounceCanUpdateUserDynamicConfigPermission(
    address spoke,
    address delegator
  ) external onlyRegisteredSpoke(spoke) {
    bytes32 key = _configKey({spoke: spoke, delegator: delegator, delegatee: msg.sender});
    ConfigPermissions oldPermissions = _config[key];
    ConfigPermissions newPermissions = oldPermissions.setCanUpdateUserDynamicConfig(false);
    _config[key] = newPermissions;

    if (!oldPermissions.eq(newPermissions)) {
      emit ConfigPermissionsUpdated(spoke, delegator, msg.sender, newPermissions);
    }
  }

  /// @inheritdoc IConfigPositionManager
  function setUsingAsCollateralOnBehalfOf(
    address spoke,
    uint256 reserveId,
    bool usingAsCollateral,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _config[_configKey({spoke: spoke, delegator: onBehalfOf, delegatee: msg.sender})]
        .canSetUsingAsCollateral(),
      CallerNotAllowed()
    );

    ISpoke(spoke).setUsingAsCollateral(reserveId, usingAsCollateral, onBehalfOf);
  }

  /// @inheritdoc IConfigPositionManager
  function updateUserRiskPremiumOnBehalfOf(
    address spoke,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _config[_configKey({spoke: spoke, delegator: onBehalfOf, delegatee: msg.sender})]
        .canUpdateUserRiskPremium(),
      CallerNotAllowed()
    );

    ISpoke(spoke).updateUserRiskPremium(onBehalfOf);
  }

  /// @inheritdoc IConfigPositionManager
  function updateUserDynamicConfigOnBehalfOf(
    address spoke,
    address onBehalfOf
  ) external onlyRegisteredSpoke(spoke) {
    require(
      _config[_configKey({spoke: spoke, delegator: onBehalfOf, delegatee: msg.sender})]
        .canUpdateUserDynamicConfig(),
      CallerNotAllowed()
    );

    ISpoke(spoke).updateUserDynamicConfig(onBehalfOf);
  }

  /// @inheritdoc IConfigPositionManager
  function getConfigPermissions(
    address spoke,
    address delegatee,
    address onBehalfOf
  ) external view returns (ConfigPermissionValues memory) {
    ConfigPermissions permissions = _config[
      _configKey({spoke: spoke, delegator: onBehalfOf, delegatee: delegatee})
    ];
    return
      ConfigPermissionValues({
        canSetUsingAsCollateral: permissions.canSetUsingAsCollateral(),
        canUpdateUserRiskPremium: permissions.canUpdateUserRiskPremium(),
        canUpdateUserDynamicConfig: permissions.canUpdateUserDynamicConfig()
      });
  }

  function _configKey(
    address spoke,
    address delegator,
    address delegatee
  ) internal pure returns (bytes32) {
    return keccak256(abi.encode(spoke, delegator, delegatee));
  }

  function _multicallEnabled() internal pure override returns (bool) {
    return true;
  }

  function _domainNameAndVersion() internal pure override returns (string memory, string memory) {
    return ('ConfigPositionManager', '1');
  }
}
