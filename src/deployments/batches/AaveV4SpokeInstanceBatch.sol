// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';

import {BatchReports} from 'src/deployments/types/BatchReports.sol';
import {AaveV4SpokeInstanceDeployProcedure} from 'src/deployments/procedures/AaveV4SpokeInstanceDeployProcedure.sol';
import {AaveV4TransparentUpgradeableProxyDeployProcedure} from 'src/deployments/procedures/AaveV4TransparentUpgradeableProxyDeployProcedure.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeConfiguratorDeployProcedure} from 'src/deployments/procedures/AaveV4SpokeConfiguratorDeployProcedure.sol';

contract AaveV4SpokeInstanceBatch is
  AaveV4SpokeInstanceDeployProcedure,
  AaveV4TransparentUpgradeableProxyDeployProcedure,
  AaveV4AaveOracleDeployProcedure,
  AaveV4SpokeConfiguratorDeployProcedure
{
  BatchReports.SpokeInstanceBatchReport internal _report;

  constructor(
    Vm vm,
    address deployer,
    address admin_,
    address accessManagerAddress_,
    uint8 oracleDecimals_,
    string memory oracleDescription_
  ) {
    address predictedSpokeInstanceAddress = vm.computeCreateAddress(
      deployer,
      vm.getNonce(deployer) + 2
    );

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

    require(spokeProxyAddress == predictedSpokeInstanceAddress, 'SpokeInstance address mismatch');

    address spokeConfiguratorAddress = _deploySpokeConfigurator(admin_);

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracleAddress: aaveOracleAddress,
      spokeImplementationAddress: spokeImplementationAddress,
      spokeProxyAddress: spokeProxyAddress,
      spokeConfiguratorAddress: spokeConfiguratorAddress
    });
  }

  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
