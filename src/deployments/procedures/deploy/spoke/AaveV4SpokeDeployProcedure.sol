// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Utils} from 'src/deployments/utils/libraries/Utils.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';

contract AaveV4SpokeDeployProcedure {
  function _deployUpgradableSpokeInstance(
    address spokeProxyAdminOwner,
    address accessManager,
    address oracle
  ) internal returns (address spokeProxy, address spokeImplementation) {
    spokeImplementation = address(new SpokeInstance({oracle_: oracle}));
    spokeProxy = Utils.proxify(
      spokeImplementation,
      spokeProxyAdminOwner,
      abi.encodeCall(SpokeInstance.initialize, (accessManager))
    );
  }
}
