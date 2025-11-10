// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/types/BatchReports.sol';
import {AaveV4AccessManagerDeployProcedure} from 'src/deployments/procedures/deploy/AaveV4AccessManagerDeployProcedure.sol';

contract AaveV4AccessBatch is AaveV4AccessManagerDeployProcedure {
  BatchReports.AccessBatchReport internal _report;

  constructor(address admin_) {
    address accessManagerAddress = _deployAccessManager(admin_);
    _report = BatchReports.AccessBatchReport({accessManagerAddress: accessManagerAddress});
  }

  function getReport() external view returns (BatchReports.AccessBatchReport memory) {
    return _report;
  }
}
