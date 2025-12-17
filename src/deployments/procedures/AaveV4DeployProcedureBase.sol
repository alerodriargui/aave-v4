// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
contract AaveV4DeployProcedureBase {
  error InvalidParam(string errorMessage);

  bytes32 public constant SALT = bytes32('v1');
  function _validateZeroAddress(address addr, string memory errorMessage) internal pure {
    require(addr != address(0), InvalidParam(errorMessage));
  }
}
