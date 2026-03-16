// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {RolesValidation} from 'src/deployments/utils/libraries/RolesValidation.sol';

library AaveV4HubConfiguratorRolesProcedure {
  /// @notice Grants all HubConfigurator granular roles (100-113) to `admin`.
  function grantHubConfiguratorAllRoles(address accessManager, address admin) internal {
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE, admin);
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_REINVESTMENT_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_HALTER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_DEACTIVATOR_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_CAPS_RESETTER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE, admin);
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(
      accessManager,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE,
      admin
    );
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_ASSET_LISTER_ROLE, admin);
    grantHubConfiguratorRole(accessManager, Roles.HUB_CONFIGURATOR_SPOKE_ADDER_ROLE, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) internal {
    RolesValidation.validateNonZeroAddress(accessManager);
    RolesValidation.validateNonZeroAddress(admin);
    IAccessManager(accessManager).grantRole({roleId: role, account: admin, executionDelay: 0});
  }

  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) internal {
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_LIQUIDITY_FEE_UPDATER_ROLE,
      Roles.getHubConfiguratorLiquidityFeeUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_FEE_CONFIGURATOR_ROLE,
      Roles.getHubConfiguratorFeeConfiguratorRoleSelectors()
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
      Roles.HUB_CONFIGURATOR_HALTER_ROLE,
      Roles.getHubConfiguratorHalterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_DEACTIVATOR_ROLE,
      Roles.getHubConfiguratorDeactivatorRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_CAPS_RESETTER_ROLE,
      Roles.getHubConfiguratorCapsResetterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_CAPS_UPDATER_ROLE,
      Roles.getHubConfiguratorCapsUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_DRAW_CAP_UPDATER_ROLE,
      Roles.getHubConfiguratorDrawCapUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_ADD_CAP_UPDATER_ROLE,
      Roles.getHubConfiguratorAddCapUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_SPOKE_RISK_ADMIN_ROLE,
      Roles.getHubConfiguratorSpokeRiskAdminRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_STRATEGY_UPDATER_ROLE,
      Roles.getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors()
    );
    setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      Roles.HUB_CONFIGURATOR_INTEREST_RATE_DATA_UPDATER_ROLE,
      Roles.getHubConfiguratorInterestRateDataUpdaterRoleSelectors()
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
