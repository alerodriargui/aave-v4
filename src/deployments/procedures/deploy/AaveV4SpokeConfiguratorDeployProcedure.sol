// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';

contract AaveV4SpokeConfiguratorDeployProcedure {
  function _deploySpokeConfigurator(address owner_) internal returns (address) {
    return address(new SpokeConfigurator({owner_: owner_}));
  }
}
