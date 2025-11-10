// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveOracle} from 'src/spoke/AaveOracle.sol';

contract AaveV4AaveOracleDeployProcedure {
  function _deployAaveOracle(
    address spoke_,
    uint8 decimals_,
    string memory description_
  ) internal returns (address) {
    address oracle = address(new AaveOracle(spoke_, decimals_, description_));

    return oracle;
  }
}
