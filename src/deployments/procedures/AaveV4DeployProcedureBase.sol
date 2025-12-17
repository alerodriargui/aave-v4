// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

contract AaveV4DeployProcedureBase {
  error InvalidParam(string errorMessage);
  function _validateZeroAddress(address addr, string memory errorMessage) internal pure {
    require(addr != address(0), InvalidParam(errorMessage));
  }
}
