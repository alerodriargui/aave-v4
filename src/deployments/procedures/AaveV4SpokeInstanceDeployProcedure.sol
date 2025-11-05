// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

contract AaveV4SpokeInstanceDeployProcedure {
  function _deploySpokeInstance(address oracle_) internal returns (address) {
    address spokeInstance = address(new SpokeInstance(oracle_));

    return spokeInstance;
  }
}
