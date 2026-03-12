// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {EngineFlags} from 'src/config-engine/libraries/EngineFlags.sol';

import {MockAccessManager} from 'tests/mocks/config-engine/MockAccessManager.sol';

contract AccessManagerEngineTest is BaseConfigEngineTest {
  function test_executeRoleMemberships_grant_concrete() public {
    IAaveV4ConfigEngine.RoleMembership[] memory memberships = _toRoleMembershipArray(
      IAaveV4ConfigEngine.RoleMembership({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        granted: true,
        executionDelay: 100
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.GrantRoleCalled(5, ACCOUNT, 100);

    engine.executeRoleMemberships(memberships);
  }

  function test_executeRoleMemberships_revoke_concrete() public {
    IAaveV4ConfigEngine.RoleMembership[] memory memberships = _toRoleMembershipArray(
      IAaveV4ConfigEngine.RoleMembership({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        granted: false,
        executionDelay: 0
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.RevokeRoleCalled(5, ACCOUNT);

    engine.executeRoleMemberships(memberships);
  }

  function test_executeRoleMemberships_grant_fuzz(
    uint64 roleId,
    address account,
    uint32 executionDelay
  ) public {
    IAaveV4ConfigEngine.RoleMembership[] memory memberships = _toRoleMembershipArray(
      IAaveV4ConfigEngine.RoleMembership({
        authority: address(mockAccessManager),
        roleId: roleId,
        account: account,
        granted: true,
        executionDelay: executionDelay
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.GrantRoleCalled(roleId, account, executionDelay);

    engine.executeRoleMemberships(memberships);
  }

  function test_executeRoleMemberships_revoke_fuzz(uint64 roleId, address account) public {
    IAaveV4ConfigEngine.RoleMembership[] memory memberships = _toRoleMembershipArray(
      IAaveV4ConfigEngine.RoleMembership({
        authority: address(mockAccessManager),
        roleId: roleId,
        account: account,
        granted: false,
        executionDelay: 0
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.RevokeRoleCalled(roleId, account);

    engine.executeRoleMemberships(memberships);
  }

  function test_executeRoleMemberships_grant_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleMembership[] memory memberships = _toRoleMembershipArray(
      IAaveV4ConfigEngine.RoleMembership({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        granted: true,
        executionDelay: 100
      })
    );

    vm.expectRevert(MockAccessManager.GrantRoleReverted.selector);
    engine.executeRoleMemberships(memberships);
  }

  function test_executeRoleMemberships_revoke_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.revokeRole.selector, true);

    IAaveV4ConfigEngine.RoleMembership[] memory memberships = _toRoleMembershipArray(
      IAaveV4ConfigEngine.RoleMembership({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        granted: false,
        executionDelay: 0
      })
    );

    vm.expectRevert(MockAccessManager.RevokeRoleReverted.selector);
    engine.executeRoleMemberships(memberships);
  }

  function test_executeRoleUpdates_allFields() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: 1,
        guardian: 2,
        grantDelay: 3600,
        label: 'FEE_UPDATER'
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleAdminCalled(5, 1);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleGuardianCalled(5, 2);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetGrantDelayCalled(5, 3600);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.LabelRoleCalled(5, 'FEE_UPDATER');

    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_adminOnly() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: 1,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: ''
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleAdminCalled(5, 1);

    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_guardianOnly() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: 2,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: ''
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleGuardianCalled(5, 2);

    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_grantDelayOnly() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: 3600,
        label: ''
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetGrantDelayCalled(5, 3600);

    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_labelOnly() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: 'FEE_UPDATER'
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.LabelRoleCalled(5, 'FEE_UPDATER');

    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_noneChanged() public {
    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: ''
      })
    );

    // No events expected — all fields are sentinels/empty
    vm.recordLogs();
    engine.executeRoleUpdates(updates);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_executeRoleUpdates_fuzz(
    uint64 roleId,
    uint64 admin,
    uint64 guardian,
    uint32 grantDelay
  ) public {
    // Use non-sentinel values so all 4 calls are made
    vm.assume(admin != EngineFlags.KEEP_CURRENT_UINT64);
    vm.assume(guardian != EngineFlags.KEEP_CURRENT_UINT64);
    vm.assume(grantDelay != EngineFlags.KEEP_CURRENT_UINT32);

    string memory label = 'FUZZ_LABEL';

    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: roleId,
        admin: admin,
        guardian: guardian,
        grantDelay: grantDelay,
        label: label
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleAdminCalled(roleId, admin);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetRoleGuardianCalled(roleId, guardian);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetGrantDelayCalled(roleId, grantDelay);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.LabelRoleCalled(roleId, label);

    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_revert_admin() public {
    mockAccessManager.setShouldRevert(IAccessManager.setRoleAdmin.selector, true);

    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: 1,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: ''
      })
    );

    vm.expectRevert(MockAccessManager.SetRoleAdminReverted.selector);
    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_revert_guardian() public {
    mockAccessManager.setShouldRevert(IAccessManager.setRoleGuardian.selector, true);

    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: 2,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: ''
      })
    );

    vm.expectRevert(MockAccessManager.SetRoleGuardianReverted.selector);
    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_revert_grantDelay() public {
    mockAccessManager.setShouldRevert(IAccessManager.setGrantDelay.selector, true);

    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: 3600,
        label: ''
      })
    );

    vm.expectRevert(MockAccessManager.SetGrantDelayReverted.selector);
    engine.executeRoleUpdates(updates);
  }

  function test_executeRoleUpdates_revert_label() public {
    mockAccessManager.setShouldRevert(IAccessManager.labelRole.selector, true);

    IAaveV4ConfigEngine.RoleUpdate[] memory updates = _toRoleUpdateArray(
      IAaveV4ConfigEngine.RoleUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: EngineFlags.KEEP_CURRENT_UINT64,
        guardian: EngineFlags.KEEP_CURRENT_UINT64,
        grantDelay: EngineFlags.KEEP_CURRENT_UINT32,
        label: 'FEE_UPDATER'
      })
    );

    vm.expectRevert(MockAccessManager.LabelRoleReverted.selector);
    engine.executeRoleUpdates(updates);
  }

  function test_executeTargetFunctionRoleUpdates_concrete() public {
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = bytes4(0xaabbccdd);
    selectors[1] = bytes4(0x11223344);

    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory updates = _toTargetFunctionRoleUpdateArray(
        IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
          authority: address(mockAccessManager),
          target: TARGET,
          selectors: selectors,
          roleId: 5
        })
      );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetTargetFunctionRoleCalled(TARGET, selectors, 5);

    engine.executeTargetFunctionRoleUpdates(updates);
  }

  function test_executeTargetFunctionRoleUpdates_fuzz(
    address target,
    bytes4 selector1,
    uint64 roleId
  ) public {
    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = selector1;

    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory updates = _toTargetFunctionRoleUpdateArray(
        IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
          authority: address(mockAccessManager),
          target: target,
          selectors: selectors,
          roleId: roleId
        })
      );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetTargetFunctionRoleCalled(target, selectors, roleId);

    engine.executeTargetFunctionRoleUpdates(updates);
  }

  function test_executeTargetFunctionRoleUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.setTargetFunctionRole.selector, true);

    bytes4[] memory selectors = new bytes4[](1);
    selectors[0] = bytes4(0xaabbccdd);

    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[]
      memory updates = _toTargetFunctionRoleUpdateArray(
        IAaveV4ConfigEngine.TargetFunctionRoleUpdate({
          authority: address(mockAccessManager),
          target: TARGET,
          selectors: selectors,
          roleId: 5
        })
      );

    vm.expectRevert(MockAccessManager.SetTargetFunctionRoleReverted.selector);
    engine.executeTargetFunctionRoleUpdates(updates);
  }

  function test_executeTargetAdminDelayUpdates_concrete() public {
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory updates = _toTargetAdminDelayUpdateArray(
      IAaveV4ConfigEngine.TargetAdminDelayUpdate({
        authority: address(mockAccessManager),
        target: TARGET,
        newDelay: 7200
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetTargetAdminDelayCalled(TARGET, 7200);

    engine.executeTargetAdminDelayUpdates(updates);
  }

  function test_executeTargetAdminDelayUpdates_fuzz(address target, uint32 newDelay) public {
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory updates = _toTargetAdminDelayUpdateArray(
      IAaveV4ConfigEngine.TargetAdminDelayUpdate({
        authority: address(mockAccessManager),
        target: target,
        newDelay: newDelay
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManager.SetTargetAdminDelayCalled(target, newDelay);

    engine.executeTargetAdminDelayUpdates(updates);
  }

  function test_executeTargetAdminDelayUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.setTargetAdminDelay.selector, true);

    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory updates = _toTargetAdminDelayUpdateArray(
      IAaveV4ConfigEngine.TargetAdminDelayUpdate({
        authority: address(mockAccessManager),
        target: TARGET,
        newDelay: 7200
      })
    );

    vm.expectRevert(MockAccessManager.SetTargetAdminDelayReverted.selector);
    engine.executeTargetAdminDelayUpdates(updates);
  }
}
