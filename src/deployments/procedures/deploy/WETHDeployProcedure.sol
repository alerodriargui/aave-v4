// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {WETH9} from 'src/dependencies/weth/WETH9.sol';

contract WETHDeployProcedure {
  function _deployWETH() internal returns (address) {
    address weth = address(new WETH9());

    return weth;
  }
}
