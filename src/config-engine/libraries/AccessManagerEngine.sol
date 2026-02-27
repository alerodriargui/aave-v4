// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/libraries/types/Roles.sol';

/// @title AccessManagerEngine
/// @author Aave Labs
/// @notice Library containing access manager logic for AaveV4ConfigEngine.
library AccessManagerEngine {
  /// @notice Grants roles via AccessManager.
  /// @param grants The role grants to execute.
  function executeRoleGrants(IAaveV4ConfigEngine.RoleGrant[] calldata grants) external {
    uint256 length = grants.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(grants[i].authority).grantRole(
        grants[i].roleId,
        grants[i].account,
        grants[i].executionDelay
      );
    }
  }

  /// @notice Revokes roles via AccessManager.
  /// @param revocations The role revocations to execute.
  function executeRoleRevocations(
    IAaveV4ConfigEngine.RoleRevocation[] calldata revocations
  ) external {
    uint256 length = revocations.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(revocations[i].authority).revokeRole(
        revocations[i].roleId,
        revocations[i].account
      );
    }
  }

  /// @notice Updates role admins via AccessManager.
  /// @param updates The role admin updates to execute.
  function executeRoleAdminUpdates(
    IAaveV4ConfigEngine.RoleAdminUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setRoleAdmin(updates[i].roleId, updates[i].admin);
    }
  }

  /// @notice Updates role guardians via AccessManager.
  /// @param updates The role guardian updates to execute.
  function executeRoleGuardianUpdates(
    IAaveV4ConfigEngine.RoleGuardianUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setRoleGuardian(updates[i].roleId, updates[i].guardian);
    }
  }

  /// @notice Updates target function roles via AccessManager.
  /// @param updates The target function role updates to execute.
  function executeTargetFunctionRoleUpdates(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setTargetFunctionRole(
        updates[i].target,
        updates[i].selectors,
        updates[i].roleId
      );
    }
  }

  /// @notice Updates target closed status via AccessManager.
  /// @param updates The target closed updates to execute.
  function executeTargetClosedUpdates(
    IAaveV4ConfigEngine.TargetClosedUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setTargetClosed(updates[i].target, updates[i].closed);
    }
  }

  /// @notice Updates role labels via AccessManager.
  /// @param updates The role label updates to execute.
  function executeRoleLabelUpdates(
    IAaveV4ConfigEngine.RoleLabelUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).labelRole(updates[i].roleId, updates[i].label);
    }
  }

  /// @notice Updates grant delays via AccessManager.
  /// @param updates The grant delay updates to execute.
  function executeGrantDelayUpdates(
    IAaveV4ConfigEngine.GrantDelayUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setGrantDelay(updates[i].roleId, updates[i].newDelay);
    }
  }

  /// @notice Updates target admin delays via AccessManager.
  /// @param updates The target admin delay updates to execute.
  function executeTargetAdminDelayUpdates(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] calldata updates
  ) external {
    uint256 length = updates.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(updates[i].authority).setTargetAdminDelay(
        updates[i].target,
        updates[i].newDelay
      );
    }
  }

  /// @notice Grants the HubConfigurator fee updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorFeeUpdaterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator reinvestment updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorReinvestmentUpdaterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator asset lister role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorAssetListerRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator spoke adder role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorSpokeAdderRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator interest rate updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorInterestRateUpdaterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator halter role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorHalterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator deactivater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorDeactivaterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the HubConfigurator caps updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorCapsUpdaterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants all HubConfigurator roles.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorAllRoles(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.HUB_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the SpokeConfigurator admin role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorAdminRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the SpokeConfigurator liquidation updater role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorLiquidationUpdaterRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the SpokeConfigurator reserve adder role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorReserveAdderRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the SpokeConfigurator freezer role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorFreezerRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  /// @notice Grants the SpokeConfigurator pauser role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorPauserRole(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  /// @notice Grants all SpokeConfigurator roles.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorAllRoles(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants
  ) external {
    _grantRoleByName(grants, Roles.SPOKE_CONFIGURATOR_ROLE);
  }

  /// @notice Grants a specific role to each account in the array via their respective AccessManager.
  /// @param grants The role grant parameters (authority + account pairs).
  /// @param roleId The role identifier to grant.
  function _grantRoleByName(
    IAaveV4ConfigEngine.RoleGrantByName[] calldata grants,
    uint64 roleId
  ) internal {
    uint256 length = grants.length;
    for (uint256 i; i < length; ++i) {
      IAccessManager(grants[i].authority).grantRole(roleId, grants[i].account, 0);
    }
  }
}
