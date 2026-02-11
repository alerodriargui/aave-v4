// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4ConfiguratorBatchTest is BatchBaseTest {
  AaveV4ConfiguratorBatch public configuratorBatch;
  BatchReports.ConfiguratorBatchReport public report;

  function setUp() public override {
    super.setUp();
    configuratorBatch = new AaveV4ConfiguratorBatch(accessManager, accessManager, salt);
    report = configuratorBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.hubConfigurator, address(0));
    assertNotEq(report.spokeConfigurator, address(0));
  }

  function test_hubConfiguratorAuthority() public view {
    assertEq(IAccessManaged(report.hubConfigurator).authority(), accessManager);
  }

  function test_spokeConfiguratorAuthority() public view {
    assertEq(IAccessManaged(report.spokeConfigurator).authority(), accessManager);
  }

  function test_revert_zeroHubConfiguratorAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4ConfiguratorBatch(address(0), accessManager, salt);
  }

  function test_revert_zeroSpokeConfiguratorAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4ConfiguratorBatch(accessManager, address(0), keccak256('zeroSpokeCfgSalt'));
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4ConfiguratorBatch newBatch = new AaveV4ConfiguratorBatch(
      accessManager,
      accessManager,
      keccak256('differentSalt')
    );
    assertNotEq(report.hubConfigurator, newBatch.getReport().hubConfigurator);
  }
}
