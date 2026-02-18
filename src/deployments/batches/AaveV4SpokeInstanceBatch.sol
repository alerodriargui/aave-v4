// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AaveOracleDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4AaveOracleDeployProcedure.sol';
import {AaveV4SpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4SpokeDeployProcedure.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';

contract AaveV4SpokeInstanceBatch is AaveV4SpokeDeployProcedure, AaveV4AaveOracleDeployProcedure {
  BatchReports.SpokeInstanceBatchReport internal _report;

  constructor(
    address spokeProxyAdminOwner_,
    address authority_,
    bytes memory spokeBytecode_,
    uint8 oracleDecimals_,
    string memory oracleDescription_,
    uint16 maxUserReservesLimit_,
    bytes32 salt_
  ) {
    bytes32 spokeInstanceSalt = keccak256(abi.encodePacked(SALT, salt_, 'spokeInstance'));
    address aaveOracle = _deployAaveOracle(oracleDecimals_, oracleDescription_);
    (address spokeProxy, address spokeImplementation) = _deployUpgradableSpokeInstance({
      spokeProxyAdminOwner: spokeProxyAdminOwner_,
      authority: authority_,
      oracle: aaveOracle,
      spokeBytecode: spokeBytecode_,
      salt: spokeInstanceSalt,
      maxUserReservesLimit: maxUserReservesLimit_
    });
    IAaveOracle(aaveOracle).setSpoke(spokeProxy);

    assert(ISpoke(spokeProxy).ORACLE() == aaveOracle);
    assert(IAaveOracle(aaveOracle).SPOKE() == spokeProxy);

    _report = BatchReports.SpokeInstanceBatchReport({
      aaveOracle: aaveOracle,
      spokeImplementation: spokeImplementation,
      spokeProxy: spokeProxy
    });
  }

  function getReport() external view returns (BatchReports.SpokeInstanceBatchReport memory) {
    return _report;
  }
}
