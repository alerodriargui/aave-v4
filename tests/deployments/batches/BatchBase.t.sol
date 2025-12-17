// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AccessBatch} from 'src/deployments/batches/AaveV4AccessBatch.sol';

import {IAccessManagerEnumerable} from 'src/access/interfaces/IAccessManagerEnumerable.sol';

contract BatchBaseTest is Test {
  address public admin = makeAddr('admin');

  function setUp() public virtual {}
}
