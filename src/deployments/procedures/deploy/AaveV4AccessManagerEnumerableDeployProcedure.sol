// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AccessManagerEnumerable} from 'src/access/AccessManagerEnumerable.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';

contract AaveV4AccessManagerEnumerableDeployProcedure is AaveV4DeployProcedureBase {
  function _deployAccessManagerEnumerable(address admin) internal returns (address) {
    _validateAddress(admin, 'admin');
    return address(new AccessManagerEnumerable({initialAdmin_: admin}));
  }
}
