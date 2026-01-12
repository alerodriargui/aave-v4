// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {DeployUtils} from 'tests/DeployUtils.sol';

contract DeployWrapper {
  function deploySpokeInstance(address oracle) external returns (address) {
    return address(DeployUtils.deploySpokeInstance(oracle));
  }

  function deployProxifiedSpokeInstance(
    address deployer,
    address oracle,
    address proxyAdminOwner,
    bytes calldata initData
  ) external returns (address) {
    return
      address(
        DeployUtils.deployProxifiedSpokeInstance(deployer, oracle, proxyAdminOwner, initData)
      );
  }

  function deployHub(address authority) external returns (address) {
    return address(DeployUtils.deployHub(authority));
  }
}
