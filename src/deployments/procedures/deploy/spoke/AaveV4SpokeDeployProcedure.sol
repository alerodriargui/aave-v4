// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Utils} from 'src/deployments/utils/libraries/Utils.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {AaveV4DeployProcedureBase} from 'src/deployments/procedures/AaveV4DeployProcedureBase.sol';

contract AaveV4SpokeDeployProcedure is AaveV4DeployProcedureBase {
  function _deployUpgradableSpokeInstance(
    address spokeProxyAdminOwner,
    address accessManager,
    address oracle
  ) internal returns (address spokeProxy, address spokeImplementation) {
    _validateAddress(spokeProxyAdminOwner, 'spoke proxy admin owner');
    _validateAddress(accessManager, 'access manager');
    _validateAddress(oracle, 'oracle');
    spokeImplementation = address(new SpokeInstance({oracle_: oracle}));
    spokeProxy = Utils.proxify(
      spokeImplementation,
      spokeProxyAdminOwner,
      abi.encodeCall(SpokeInstance.initialize, (accessManager))
    );
    return (spokeProxy, spokeImplementation);
  }
}
