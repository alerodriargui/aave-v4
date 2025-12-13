// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

contract AaveV4SpokeInstanceDeployProcedure {
  function _deploySpokeInstance(address oracle_) internal returns (address) {
    return address(new SpokeInstance({oracle_: oracle_}));
  }
}
