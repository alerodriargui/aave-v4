// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';

contract AaveV4AaveOracleDeployProcedure {
  function _deployAaveOracle(
    address spoke_,
    uint8 decimals_,
    string memory description_
  ) internal returns (address) {
    return
      address(new AaveOracle({spoke_: spoke_, decimals_: decimals_, description_: description_}));
  }
}
