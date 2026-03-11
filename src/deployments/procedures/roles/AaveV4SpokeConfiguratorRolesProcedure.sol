// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4SpokeConfiguratorRolesProcedure {
  /// @notice Grants all SpokeConfigurator granular roles (301-309) to `admin`.
  function grantSpokeConfiguratorAllRoles(address accessManager, address admin) internal {
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE, admin);
    grantSpokeConfiguratorRole(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE,
      admin
    );
    grantSpokeConfiguratorRole(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE,
      admin
    );
    grantSpokeConfiguratorRole(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      admin
    );
    grantSpokeConfiguratorRole(
      accessManager,
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE,
      admin
    );
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE, admin);
    grantSpokeConfiguratorRole(accessManager, Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE, admin);
  }

  function grantSpokeConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  function setupSpokeConfiguratorAllRoles(
    address accessManager,
    address spokeConfigurator
  ) internal {
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_PRICE_ADMIN_ROLE,
      Roles.getSpokeConfiguratorPriceAdminRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADMIN_ROLE,
      Roles.getSpokeConfiguratorReserveAdminRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_RESERVE_ADMIN_ROLE,
      Roles.getSpokeConfiguratorDynamicReserveAdminRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_POSITION_MANAGER_ADMIN_ROLE,
      Roles.getSpokeConfiguratorPositionManagerAdminRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_LIQUIDATION_UPDATER_ROLE,
      Roles.getSpokeConfiguratorLiquidationUpdaterRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_DYNAMIC_LIQUIDATION_UPDATER_ROLE,
      Roles.getSpokeConfiguratorDynamicLiquidationUpdaterRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_RESERVE_ADDER_ROLE,
      Roles.getSpokeConfiguratorReserveAdderRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_FREEZER_ROLE,
      Roles.getSpokeConfiguratorFreezerRoleSelectors()
    );
    setupSpokeConfiguratorRole(
      accessManager,
      spokeConfigurator,
      Roles.SPOKE_CONFIGURATOR_PAUSER_ROLE,
      Roles.getSpokeConfiguratorPauserRoleSelectors()
    );
  }

  function setupSpokeConfiguratorRole(
    address accessManager,
    address spokeConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(spokeConfigurator);
    IAccessManager(accessManager).setTargetFunctionRole(spokeConfigurator, selectors, role);
  }
}
