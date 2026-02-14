// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4SpokeInstanceBatchTest is BatchBaseTest {
  AaveV4SpokeInstanceBatch public spokeBatch;
  BatchReports.SpokeInstanceBatchReport public report;

  function setUp() public override {
    super.setUp();
    spokeBatch = new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      spokeBytecode,
      8,
      'Test',
      128,
      salt
    );
    report = spokeBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.spokeProxy, address(0));
    assertNotEq(report.spokeImplementation, address(0));
    assertNotEq(report.aaveOracle, address(0));
  }

  function test_spokeAuthority() public view {
    assertEq(IAccessManaged(report.spokeProxy).authority(), accessManager);
  }

  function test_spokeOracle() public view {
    assertEq(ISpoke(report.spokeProxy).ORACLE(), report.aaveOracle);
  }

  function test_spokeMaxUserReservesLimit() public view {
    assertEq(ISpoke(report.spokeProxy).MAX_USER_RESERVES_LIMIT(), 128);
  }

  function test_oracleWiring() public view {
    assertEq(IPriceOracle(report.aaveOracle).SPOKE(), report.spokeProxy);
    assertEq(IPriceOracle(report.aaveOracle).DECIMALS(), 8);
  }

  function test_revert_zeroAuthority() public {
    vm.expectRevert('invalid authority');
    new AaveV4SpokeInstanceBatch(admin, address(0), spokeBytecode, 8, 'Test', 128, salt);
  }

  function test_revert_zeroSpokeProxyAdminOwner() public {
    vm.expectRevert('invalid spoke proxy admin owner');
    new AaveV4SpokeInstanceBatch(address(0), accessManager, spokeBytecode, 8, 'Test', 128, salt);
  }

  function test_revert_zeroOracleDecimals() public {
    vm.expectRevert('invalid oracle decimals');
    new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      spokeBytecode,
      0,
      'Test',
      128,
      keccak256('zeroDecimalsSalt')
    );
  }

  function test_revert_emptyOracleDescription() public {
    vm.expectRevert('invalid oracle description');
    new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      spokeBytecode,
      8,
      '',
      128,
      keccak256('emptyDescSalt')
    );
  }

  function test_revert_zeroMaxUserReservesLimit() public {
    vm.expectRevert('invalid max user reserves limit');
    new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      spokeBytecode,
      8,
      'Test',
      0,
      keccak256('zeroMaxReservesSalt')
    );
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4SpokeInstanceBatch newBatch = new AaveV4SpokeInstanceBatch(
      admin,
      accessManager,
      spokeBytecode,
      8,
      'Test',
      128,
      keccak256('differentSalt')
    );
    assertNotEq(report.spokeProxy, newBatch.getReport().spokeProxy);
  }
}
