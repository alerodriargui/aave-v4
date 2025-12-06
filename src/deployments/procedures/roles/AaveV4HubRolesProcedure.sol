// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Roles} from 'src/libraries/types/Roles.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

library AaveV4HubRolesProcedure {
  function setHubRoles(address accessManagerAddress, address hubAddress) internal {
    bytes4[] memory selectors = new bytes4[](6);
    selectors[0] = IHub.addAsset.selector;
    selectors[1] = IHub.updateAssetConfig.selector;
    selectors[2] = IHub.addSpoke.selector;
    selectors[3] = IHub.updateSpokeConfig.selector;
    selectors[4] = IHub.setInterestRateData.selector;
    selectors[5] = IHub.mintFeeShares.selector;
    IAccessManager(accessManagerAddress).setTargetFunctionRole(
      hubAddress,
      selectors,
      Roles.HUB_ADMIN_ROLE
    );
  }
}
