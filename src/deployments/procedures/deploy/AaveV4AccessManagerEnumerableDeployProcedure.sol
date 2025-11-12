// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract AaveV4AccessManagerEnumerableDeployProcedure {
  function _deployAccessManagerEnumerable(address admin_) internal returns (address) {
    address accessManager = address(new AccessManagerEnumerable(admin_));

    return accessManager;
  }
}
