// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';
library AaveV4HubConfiguratorRolesProcedure {
  /// @notice Grants all HubConfigurator granular roles to `admin`:
  ///   - HUB_CONFIGURATOR_FEE_UPDATER_ROLE
  ///   - HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE
  ///   - HUB_CONFIGURATOR_ASSET_LISTER_ROLE
  ///   - HUB_CONFIGURATOR_SPOKE_ADDER_ROLE
  ///   - HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE
  ///   - HUB_CONFIGURATOR_HALTER_ROLE
  ///   - HUB_CONFIGURATOR_DEACTIVATER_ROLE
  ///   - HUB_CONFIGURATOR_CAPS_UDPATER_ROLE
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE, admin);
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE, admin);
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_HALTER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  /// @notice Maps HubConfigurator function selectors to their roles:
  ///   - FeeUpdaterRoleSelectors -> HUB_CONFIGURATOR_FEE_UPDATER_ROLE
  ///   - ReinvestmentUpdaterRoleSelectors -> HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE
  ///   - AssetListerRoleSelectors -> HUB_CONFIGURATOR_ASSET_LISTER_ROLE
  ///   - SpokeAdderRoleSelectors -> HUB_CONFIGURATOR_SPOKE_ADDER_ROLE
  ///   - InterestRateUpdaterRoleSelectors -> HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE
  ///   - HalterRoleSelectors -> HUB_CONFIGURATOR_HALTER_ROLE
  ///   - ActivaterRoleSelectors -> HUB_CONFIGURATOR_DEACTIVATER_ROLE
  ///   - CapSetterRoleSelectors -> HUB_CONFIGURATOR_CAPS_UDPATER_ROLE
  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) internal {
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_FEE_UPDATER_ROLE,
      Roles.getHubConfiguratorFeeUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      Roles.getHubConfiguratorReinvestmentUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE,
      Roles.getHubConfiguratorAssetListerRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE,
      Roles.getHubConfiguratorSpokeAdderRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_UPDATER_ROLE,
      Roles.getHubConfiguratorInterestRateUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_HALTER_ROLE,
      Roles.getHubConfiguratorHalterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_DEACTIVATER_ROLE,
      Roles.getHubConfiguratorActivaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_CAPS_UDPATER_ROLE,
      Roles.getHubConfiguratorCapSetterRoleSelectors()
    );
  }

  function setupHubConfiguratorRole(
    address accessManager,
    address hubConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(hubConfigurator);
    IAccessManager(accessManager).setTargetFunctionRole(hubConfigurator, selectors, role);
  }
}
