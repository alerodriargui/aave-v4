// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';

contract AaveV4AccessManagerEnumerableDeployProcedure {
  function _deployAccessManagerEnumerable(address admin_) internal returns (address) {
    return address(new AccessManagerEnumerable({initialAdmin_: admin_}));
  }
}
