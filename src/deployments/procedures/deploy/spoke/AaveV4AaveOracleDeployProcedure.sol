// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4AaveOracleDeployProcedure is AaveV4DeployProcedureBase {
  function _deployAaveOracle(
    address spoke_,
    uint8 decimals_,
    string memory description_,
    bytes32 salt_
  ) internal returns (address) {
    require(spoke_ != address(0), 'invalid spoke');
    require(decimals_ > 0, 'invalid oracle decimals');
    require(bytes(description_).length > 0, 'invalid oracle description');
    // AaveOracle must be deployed via create to compute the predicted address via without inputs
    return
      address(new AaveOracle({spoke_: spoke_, decimals_: decimals_, description_: description_}));
  }
}
