// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IProgressLogger} from 'src/deployments/utils/interfaces/IProgressLogger.sol';
import {console2 as console} from 'forge-std/console2.sol';

contract MockLogger is IProgressLogger {
  function log(string memory label, address value) external pure {
    // console.log(label, value);
  }

  function log(string memory label, uint256 value) external pure {
    // console.log(label, value);
  }

  function log(string memory value) external pure {
    // console.log(value);
  }
}
