// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';

contract AaveV4TreasurySpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployTreasurySpoke(address owner, address hub) internal returns (address) {
    _validateZeroAddress(owner, 'owner');
    _validateZeroAddress(hub, 'hub');
    return address(new TreasurySpoke({owner_: owner, hub_: hub}));
  }
}
