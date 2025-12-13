// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'scripts/deploy/AaveV4DeployBatchBase.s.sol';

contract AaveV4DeployBatchScript is AaveV4DeployBatchBaseScript {
  string internal constant INPUT_FILE = 'AaveV4DeployInput.json';
  string internal constant OUTPUT_FILE = 'AaveV4DeployBatch.json';
  constructor() AaveV4DeployBatchBaseScript(INPUT_FILE, OUTPUT_FILE) {}
}
