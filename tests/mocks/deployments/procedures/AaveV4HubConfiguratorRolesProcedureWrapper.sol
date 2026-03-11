// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4HubConfiguratorRolesProcedure} from 'src/deployments/procedures/roles/AaveV4HubConfiguratorRolesProcedure.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';

contract AaveV4HubConfiguratorRolesProcedureWrapper {
  bool public IS_TEST = true;

  function grantHubConfiguratorAllRoles(address accessManager, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorAllRoles(accessManager, admin);
  }

  function grantHubConfiguratorRole(address accessManager, uint64 role, address admin) external {
    AaveV4HubConfiguratorRolesProcedure.grantHubConfiguratorRole(accessManager, role, admin);
  }

  function setupHubConfiguratorAllRoles(address accessManager, address hubConfigurator) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorAllRoles(
      accessManager,
      hubConfigurator
    );
  }

  function setupHubConfiguratorRole(
    address accessManager,
    address hubConfigurator,
    uint64 role,
    bytes4[] memory selectors
  ) external {
    AaveV4HubConfiguratorRolesProcedure.setupHubConfiguratorRole(
      accessManager,
      hubConfigurator,
      role,
      selectors
    );
  }

  function getHubConfiguratorLiquidityFeeUpdaterRoleSelectors()
    external
    pure
    returns (bytes4[] memory)
  {
    return Roles.getHubConfiguratorLiquidityFeeUpdaterRoleSelectors();
  }

  function getHubConfiguratorFeeConfiguratorRoleSelectors()
    external
    pure
    returns (bytes4[] memory)
  {
    return Roles.getHubConfiguratorFeeConfiguratorRoleSelectors();
  }

  function getHubConfiguratorReinvestmentUpdaterRoleSelectors()
    external
    pure
    returns (bytes4[] memory)
  {
    return Roles.getHubConfiguratorReinvestmentUpdaterRoleSelectors();
  }

  function getHubConfiguratorHalterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorHalterRoleSelectors();
  }

  function getHubConfiguratorDeactivatorRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorDeactivatorRoleSelectors();
  }

  function getHubConfiguratorCapsResetterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorCapsResetterRoleSelectors();
  }

  function getHubConfiguratorCapsUpdaterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorCapsUpdaterRoleSelectors();
  }

  function getHubConfiguratorDrawCapUpdaterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorDrawCapUpdaterRoleSelectors();
  }

  function getHubConfiguratorAddCapUpdaterRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorAddCapUpdaterRoleSelectors();
  }

  function getHubConfiguratorSpokeRiskAdminRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorSpokeRiskAdminRoleSelectors();
  }

  function getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors()
    external
    pure
    returns (bytes4[] memory)
  {
    return Roles.getHubConfiguratorInterestRateStrategyUpdaterRoleSelectors();
  }

  function getHubConfiguratorInterestRateDataUpdaterRoleSelectors()
    external
    pure
    returns (bytes4[] memory)
  {
    return Roles.getHubConfiguratorInterestRateDataUpdaterRoleSelectors();
  }

  function getHubConfiguratorAssetListerRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorAssetListerRoleSelectors();
  }

  function getHubConfiguratorSpokeAdderRoleSelectors() external pure returns (bytes4[] memory) {
    return Roles.getHubConfiguratorSpokeAdderRoleSelectors();
  }
}
