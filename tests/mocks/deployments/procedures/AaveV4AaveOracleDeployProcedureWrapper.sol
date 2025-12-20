// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {
  AaveV4AaveOracleDeployProcedure
} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';

contract AaveV4AaveOracleDeployProcedureWrapper is AaveV4AaveOracleDeployProcedure {
  bool public IS_TEST = true;

  function deployAaveOracle(
    address spoke,
    uint8 decimals,
    string memory description,
    bytes32 salt
  ) external returns (address) {
    return _deployAaveOracle(spoke, decimals, description, salt);
  }
}
