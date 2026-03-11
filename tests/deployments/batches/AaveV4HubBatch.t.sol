// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4HubBatchTest is BatchBaseTest {
  AaveV4HubBatch public hubBatch;
  BatchReports.HubBatchReport public report;

  function setUp() public override {
    super.setUp();
    hubBatch = new AaveV4HubBatch({
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: salt
    });
    report = hubBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hub, address(0));
    assertNotEq(report.irStrategy, address(0));
  }

  function test_hubAuthority() public view {
    assertEq(IAccessManaged(report.hub).authority(), accessManager);
  }

  function test_irStrategyHub() public view {
    assertEq(AssetInterestRateStrategy(report.irStrategy).HUB(), report.hub);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4HubBatch({authority_: address(0), hubBytecode_: hubBytecode, salt_: salt});
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4HubBatch newBatch = new AaveV4HubBatch({
      authority_: accessManager,
      hubBytecode_: hubBytecode,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(report.hub, newBatch.getReport().hub);
  }
}
