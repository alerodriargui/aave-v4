// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Hub} from 'src/hub/Hub.sol';

contract AaveV4HubDeployProcedure {
  function _deployHub(address accessManager_) internal returns (address) {
    address hub = address(new Hub(accessManager_));

    return hub;
  }
}
