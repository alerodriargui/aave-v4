// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4AccessManagerEnumerableDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4AccessManagerEnumerableDeployProcedure.sol';

contract AaveV4AccessBatch is AaveV4AccessManagerEnumerableDeployProcedure {
  BatchReports.AccessBatchReport internal _report;

  constructor(address admin_, bytes32 salt_) {
    address accessManager = _deployAccessManagerEnumerable(
      admin_,
      keccak256(abi.encodePacked(SALT, salt_, 'accessManager'))
    );
    _report = BatchReports.AccessBatchReport({accessManager: accessManager});
  }

  function getReport() external view returns (BatchReports.AccessBatchReport memory) {
    return _report;
  }
}
