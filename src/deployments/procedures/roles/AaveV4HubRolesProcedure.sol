// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

library AaveV4HubRolesProcedure {
  function grantHubAdminRole(address accessManagerAddress, address admin) internal {
    grantHubFeeMinterRole(accessManagerAddress, admin);
    grantHubConfiguratorRole(accessManagerAddress, admin);
  }

  function grantHubFeeMinterRole(address accessManagerAddress, address admin) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.HUB_FEE_MINTER_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function grantHubConfiguratorRole(address accessManagerAddress, address admin) internal {
    IAccessManager(accessManagerAddress).grantRole({
      roleId: Roles.HUB_CONFIGURATOR_ROLE,
      account: admin,
      executionDelay: 0
    });
  }

  function setHubRoles(address accessManagerAddress, address hubAddress) internal {
    setHubFeeMinterRole(accessManagerAddress, hubAddress);
    setHubConfiguratorRole(accessManagerAddress, hubAddress);
  }

  function setHubFeeMinterRole(address accessManagerAddress, address hubAddress) internal {
    bytes4[] memory selectors = getHubFeeMinterRoleSelectors();
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      hubAddress,
      selectors,
      Roles.HUB_FEE_MINTER_ROLE
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

  function getHubFeeMinterRoleSelectors() internal pure returns (bytes4[] memory) {
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
