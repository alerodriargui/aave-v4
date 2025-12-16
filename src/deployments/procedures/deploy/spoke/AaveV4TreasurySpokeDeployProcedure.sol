// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';

contract AaveV4TreasurySpokeDeployProcedure {
  function _deployTreasurySpoke(address owner, address hub) internal returns (address) {
    return address(new TreasurySpoke({owner_: owner, hub_: hub}));
  }
}
