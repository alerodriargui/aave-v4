// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';

contract AaveV4TreasurySpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployTreasurySpoke(
    address owner,
    address hub,
    bytes32 salt
  ) internal returns (address) {
    require(owner != address(0), 'invalid owner');
    require(hub != address(0), 'invalid hub');
    return
      Create2Utils.create2Deploy(
        salt,
        abi.encodePacked(type(TreasurySpoke).creationCode, abi.encode(owner, hub))
      );
  }
}
