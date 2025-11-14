// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';

contract AaveV4TransparentUpgradeableProxyDeployProcedure {
  function _proxify(
    address logic_,
    address initialOwner_,
    bytes memory data_
  ) internal returns (address) {
    address proxy = address(new TransparentUpgradeableProxy(logic_, initialOwner_, data_));

    return proxy;
  }
}
