// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {console2 as console} from 'forge-std/console2.sol';

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {
  AaveV4SpokeInstanceDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4SpokeInstanceDeployProcedure.sol';
import {
  AaveV4TransparentUpgradeableProxyDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4TransparentUpgradeableProxyDeployProcedure.sol';
import {
  AaveV4AaveOracleDeployProcedure
} from 'src/deployments/procedures/deploy/AaveV4AaveOracleDeployProcedure.sol';

contract AaveV4SpokeInstanceBatch is
  AaveV4SpokeInstanceDeployProcedure,
  AaveV4TransparentUpgradeableProxyDeployProcedure,
  AaveV4AaveOracleDeployProcedure
{
  BatchReports.SpokeInstanceBatchReport internal _report;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  constructor(
    address admin_,
    address accessManagerAddress_,
    uint8 oracleDecimals_,
    string memory oracleDescription_
  ) {
    // address predictedSpokeInstanceAddress = vm.computeCreateAddress(
    //   address(this),
    //   vm.getNonce(address(this)) + 2
    // );

    address predictedSpokeInstanceAddress = address(this); // TODO: FIX

    address aaveOracleAddress = _deployAaveOracle(
      predictedSpokeInstanceAddress,
      oracleDecimals_,
      oracleDescription_
    );
    address spokeImplementationAddress = _deploySpokeInstance(aaveOracleAddress);
    address spokeProxyAddress = _proxify(
      spokeImplementationAddress,
      admin_,
      abi.encodeWithSignature('initialize(address)', accessManagerAddress_)
    );

    // require(spokeProxyAddress == predictedSpokeInstanceAddress_, 'SpokeInstance address mismatch');  // uncomment when fixed

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracleAddress: aaveOracleAddress,
      spokeImplementationAddress: spokeImplementationAddress,
      spokeProxyAddress: spokeProxyAddress
    });
  }

  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
