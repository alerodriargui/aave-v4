// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4TestOrchestration} from 'tests/deployments/orchestration/AaveV4TestOrchestration.sol';

contract AaveV4TestOrchestrationWrapper {
  function deploySpokeImplementation(
    address oracle,
    uint16 maxUserReservesLimit
  ) external returns (address) {
    return address(AaveV4TestOrchestration.deploySpokeImplementation(oracle, maxUserReservesLimit));
  }

  function deploySpoke(
    address oracle,
    uint16 maxUserReservesLimit,
    address proxyAdminOwner,
    bytes calldata initData
  ) external returns (address) {
    return
      address(
        AaveV4TestOrchestration.deploySpoke(oracle, maxUserReservesLimit, proxyAdminOwner, initData)
      );
  }

  function deployHub(address proxyAdminOwner, address authority) external returns (address) {
    return address(AaveV4TestOrchestration.deployHub(proxyAdminOwner, authority));
  }
}
