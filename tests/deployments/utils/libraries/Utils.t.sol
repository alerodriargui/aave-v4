// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Utils} from 'src/deployments/utils/libraries/Utils.sol';
import {Test} from 'forge-std/Test.sol';

contract UtilsTest is Test {
  function testComputeCreateAddress_fuzz(address deployer, uint8 nonce) public {
    vm.assume(deployer != address(0));
    vm.assume(nonce < 0x80);
    address expected = vm.computeCreateAddress(deployer, nonce);
    assertEq(Utils.computeCreateAddress(deployer, nonce), expected);
  }
}
