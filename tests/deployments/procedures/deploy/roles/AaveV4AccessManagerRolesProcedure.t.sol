// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/procedures/ProceduresBase.t.sol';

contract AaveV4AccessManagerRolesProcedureTest is ProceduresBase {
  AaveV4AccessManagerRolesProcedureWrapper public aaveV4AccessManagerRolesProcedureWrapper;
  function setUp() public override {
    super.setUp();
    aaveV4AccessManagerRolesProcedureWrapper = new AaveV4AccessManagerRolesProcedureWrapper();
  }

  function test_grantRootAdminRole() public {
    address newAdmin = makeAddr('newAdmin');

    _grantTmpRootAdminRole(newAdmin);
    (bool hasRole, uint32 executionDelay) = IAccessManagerEnumerable(accessManager).hasRole(
      Roles.DEFAULT_ADMIN_ROLE,
      newAdmin
    );
    assertTrue(hasRole);
    assertEq(executionDelay, 0);
  }

  function test_grantRootAdminRole_reverts() public {
    address newAdmin = makeAddr('newAdmin');
    vm.expectRevert('invalid access manager');
    aaveV4AccessManagerRolesProcedureWrapper.grantRootAdminRole({
      accessManager: address(0),
      adminToAdd: newAdmin,
      adminToRemove: address(0)
    });

    vm.expectRevert('invalid admin to add');
    aaveV4AccessManagerRolesProcedureWrapper.grantRootAdminRole({
      accessManager: accessManager,
      adminToAdd: address(0),
      adminToRemove: newAdmin
    });

    vm.expectRevert('invalid admin to remove');
    aaveV4AccessManagerRolesProcedureWrapper.grantRootAdminRole({
      accessManager: accessManager,
      adminToAdd: newAdmin,
      adminToRemove: address(0)
    });
  }

  /// @dev Grants a temporary root admin role to the wrapper contract to execute the procedure.
  function _grantTmpRootAdminRole(address newAdmin) internal {
    vm.startPrank(accessManagerAdmin);
    IAccessManager(accessManager).grantRole(
      Roles.DEFAULT_ADMIN_ROLE,
      address(aaveV4AccessManagerRolesProcedureWrapper),
      0
    );
    aaveV4AccessManagerRolesProcedureWrapper.grantRootAdminRole({
      accessManager: accessManager,
      adminToAdd: newAdmin,
      adminToRemove: address(aaveV4AccessManagerRolesProcedureWrapper)
    });
    vm.stopPrank();
  }
}
