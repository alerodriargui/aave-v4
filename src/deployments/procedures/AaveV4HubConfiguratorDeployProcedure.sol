// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {HubConfigurator} from 'src/hub/HubConfigurator.sol';

contract AaveV4HubConfiguratorDeployProcedure {
  function _deployHubConfigurator(address owner_) internal returns (address) {
    address hubConfigurator = address(new HubConfigurator(owner_));

    return hubConfigurator;
  }
}
