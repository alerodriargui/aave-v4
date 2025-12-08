// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

library AaveV4HubRolesProcedure {
  function grantHubAdminRole(address accessManagerAddress, address hubAdminAddress) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.HUB_ADMIN_ROLE,
      account: hubAdminAddress,
      executionDelay: 0
    });
    grantHubConfiguratorRole(accessManagerAddress, hubAdminAddress);
  }

  function grantHubConfiguratorRole(
    address accessManagerAddress,
    address hubConfiguratorAddress
  ) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: hubConfiguratorAddress,
      executionDelay: 0
    });
  }

  function setHubRoles(address accessManagerAddress, address hubAddress) internal {
    setHubAdminRole(accessManagerAddress, hubAddress);
    setHubConfiguratorRole(accessManagerAddress, hubAddress);
  }

  function setHubAdminRole(address accessManagerAddress, address hubAddress) internal {
    bytes4[] memory selectors = getHubAdminRoleSelectors();
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      hubAddress,
      selectors,
      Roles.HUB_ADMIN_ROLE
    );
  }

  function setHubConfiguratorRole(address accessManagerAddress, address hubAddress) internal {
    bytes4[] memory selectors = getHubConfiguratorRoleSelectors();
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      hubAddress,
      selectors,
      Roles.HUB_CONFIGURATOR_ROLE
    );
  }

  function getHubAdminRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = IHub.mintFeeShares.selector;
    return selectors;
  }

  function getHubConfiguratorRoleSelectors() internal pure returns (bytes4[] memory) {
    bytes4[] memory selectors = new bytes4[](5);
    selectors[0] = IHub.addAsset.selector;
    selectors[1] = IHub.updateAssetConfig.selector;
    selectors[2] = IHub.addSpoke.selector;
    selectors[3] = IHub.updateSpokeConfig.selector;
    selectors[4] = IHub.setInterestRateData.selector;
    return selectors;
  }
}
