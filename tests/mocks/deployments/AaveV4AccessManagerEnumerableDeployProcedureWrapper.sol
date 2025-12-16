// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4AccessManagerEnumerableDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4AccessManagerEnumerableDeployProcedure.sol';

contract AaveV4AccessManagerEnumerableDeployProcedureWrapper is
  AaveV4AccessManagerEnumerableDeployProcedure
{
  function deployAccessManagerEnumerable(address admin) external returns (address) {
    return _deployAccessManagerEnumerable(admin);
  }
}
