// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';

contract AaveV4AccessManagerDeployProcedure {
  function _deployAccessManager(address admin_) internal returns (address) {
    address accessManager = address(new AccessManager(admin_));

    return accessManager;
  }
}
