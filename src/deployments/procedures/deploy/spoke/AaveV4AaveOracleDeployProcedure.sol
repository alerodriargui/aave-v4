// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';
contract AaveV4AaveOracleDeployProcedure is AaveV4DeployProcedureBase {
  function _deployAaveOracle(
    address spoke_,
    uint8 decimals_,
    string memory description_
  ) internal returns (address) {
    _validateZeroAddress(spoke_, 'spoke');
    require(decimals_ > 0, InvalidParam('oracle decimals'));
    require(bytes(description_).length > 0, InvalidParam('oracle description'));
    return
      address(new AaveOracle({spoke_: spoke_, decimals_: decimals_, description_: description_}));
  }
}
