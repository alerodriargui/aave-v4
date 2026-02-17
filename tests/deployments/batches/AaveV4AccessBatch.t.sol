// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4AccessBatchTest is BatchBaseTest {
  AaveV4AccessBatch public aaveV4AccessBatch;
  function setUp() public override {
    super.setUp();
    bytes32 accessSalt = keccak256('accessBatchSalt');
    aaveV4AccessBatch = new AaveV4AccessBatch({admin_: admin, salt_: accessSalt});
  }

  function test_getReport() public view {
    BatchReports.AccessBatchReport memory report = aaveV4AccessBatch.getReport();
    assertNotEq(report.accessManager, address(0));

    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(report.accessManager).hasRole(
      Roles.DEFAULT_ADMIN_ROLE,
      admin
    );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }

  function test_revert_zeroAdmin() public {
    vm.expectRevert('invalid admin');
    new AaveV4AccessBatch({admin_: address(0), salt_: keccak256('zeroAdminSalt')});
  }

  function test_adminRoleMemberTracking() public view {
    IAccessManagerEnumerable am = IAccessManagerEnumerable(
      aaveV4AccessBatch.getReport().accessManager
    );
    assertEq(am.getRoleMemberCount(Roles.DEFAULT_ADMIN_ROLE), 1);
    assertEq(am.getRoleMember(Roles.DEFAULT_ADMIN_ROLE, 0), admin);
  }

  function test_noOtherRolesInitialized() public view {
    IAccessManagerEnumerable am = IAccessManagerEnumerable(
      aaveV4AccessBatch.getReport().accessManager
    );
    assertEq(am.getRoleCount(), 0);
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4AccessBatch newBatch = new AaveV4AccessBatch({
      admin_: admin,
      salt_: keccak256('differentSalt')
    });
    assertNotEq(aaveV4AccessBatch.getReport().accessManager, newBatch.getReport().accessManager);
  }
}
