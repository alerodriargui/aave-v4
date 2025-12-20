// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';

contract AaveV4SpokeConfiguratorDeployProcedure is AaveV4DeployProcedureBase {
  function _deploySpokeConfigurator(address owner, bytes32 salt) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(SpokeConfigurator).creationCode, abi.encode(owner))
      );
  }
}
