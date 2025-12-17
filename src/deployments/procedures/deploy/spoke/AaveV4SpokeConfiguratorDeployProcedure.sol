// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';

contract AaveV4SpokeConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  function _deploySpokeConfigurator(address owner) internal returns (address) {
    _validateZeroAddress(owner, 'owner');
    return address(new SpokeConfigurator({owner_: owner}));
  }
}
