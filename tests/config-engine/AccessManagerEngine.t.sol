// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/IAaveV4ConfigEngine.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {MockAccessManagerForEngine} from 'tests/mocks/config-engine/MockAccessManagerForEngine.sol';

contract AccessManagerEngineTest is BaseConfigEngineTest {
  // Re-declare diagnostic events from MockAccessManagerForEngine for vm.expectEmit
  event GrantRoleCalled(uint64 roleId, address account, uint32 executionDelay);
  event RevokeRoleCalled(uint64 roleId, address account);
  event SetRoleAdminCalled(uint64 roleId, uint64 admin);
  event SetRoleGuardianCalled(uint64 roleId, uint64 guardian);
  event SetTargetFunctionRoleCalled(address target, bytes4[] selectors, uint64 roleId);
  event SetTargetClosedCalled(address target, bool closed);
  event LabelRoleCalled(uint64 roleId, string label);
  event SetGrantDelayCalled(uint64 roleId, uint32 newDelay);
  event SetTargetAdminDelayCalled(address target, uint32 newDelay);

  // Secondary account for multi-account tests
  address constant ACCOUNT2 = address(0x7002);

  // ============================================================
  // Helpers
  // ============================================================

  function _toRoleGrantArray(
    IAaveV4ConfigEngine.RoleGrant memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleGrant[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleGrant[](1);
    arr[0] = item;
  }

  function _toRoleRevocationArray(
    IAaveV4ConfigEngine.RoleRevocation memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleRevocation[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleRevocation[](1);
    arr[0] = item;
  }

  function _toRoleAdminUpdateArray(
    IAaveV4ConfigEngine.RoleAdminUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleAdminUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleAdminUpdate[](1);
    arr[0] = item;
  }

  function _toRoleGuardianUpdateArray(
    IAaveV4ConfigEngine.RoleGuardianUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleGuardianUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleGuardianUpdate[](1);
    arr[0] = item;
  }

  function _toTargetFunctionRoleUpdateArray(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.TargetFunctionRoleUpdate[](1);
    arr[0] = item;
  }

  function _toTargetClosedUpdateArray(
    IAaveV4ConfigEngine.TargetClosedUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.TargetClosedUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.TargetClosedUpdate[](1);
    arr[0] = item;
  }

  function _toRoleLabelUpdateArray(
    IAaveV4ConfigEngine.RoleLabelUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleLabelUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleLabelUpdate[](1);
    arr[0] = item;
  }

  function _toGrantDelayUpdateArray(
    IAaveV4ConfigEngine.GrantDelayUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.GrantDelayUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.GrantDelayUpdate[](1);
    arr[0] = item;
  }

  function _toTargetAdminDelayUpdateArray(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate memory item
  ) internal pure returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory arr) {
    arr = new IAaveV4ConfigEngine.TargetAdminDelayUpdate[](1);
    arr[0] = item;
  }

  function _toRoleGrantByNameArray(
    IAaveV4ConfigEngine.RoleGrantByName memory item
  ) internal pure returns (IAaveV4ConfigEngine.RoleGrantByName[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleGrantByName[](1);
    arr[0] = item;
  }

  function _toRoleGrantByNameArray2(
    IAaveV4ConfigEngine.RoleGrantByName memory item1,
    IAaveV4ConfigEngine.RoleGrantByName memory item2
  ) internal pure returns (IAaveV4ConfigEngine.RoleGrantByName[] memory arr) {
    arr = new IAaveV4ConfigEngine.RoleGrantByName[](2);
    arr[0] = item1;
    arr[1] = item2;
  }

  function _defaultRoleGrantByName()
    internal
    view
    returns (IAaveV4ConfigEngine.RoleGrantByName memory)
  {
    return
      IAaveV4ConfigEngine.RoleGrantByName({
        authority: address(mockAccessManager),
        account: ACCOUNT
      });
  }

  // ============================================================
  // 1. executeRoleGrants
  // ============================================================

  function test_executeRoleGrants_concrete() public {
    IAaveV4ConfigEngine.RoleGrant[] memory grants = _toRoleGrantArray(
      IAaveV4ConfigEngine.RoleGrant({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        executionDelay: 100
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(5, ACCOUNT, 100);

    engine.executeRoleGrants(grants);
  }

  function test_executeRoleGrants_fuzz(
    uint64 roleId,
    address account,
    uint32 executionDelay
  ) public {
    IAaveV4ConfigEngine.RoleGrant[] memory grants = _toRoleGrantArray(
      IAaveV4ConfigEngine.RoleGrant({
        authority: address(mockAccessManager),
        roleId: roleId,
        account: account,
        executionDelay: executionDelay
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(roleId, account, executionDelay);

    engine.executeRoleGrants(grants);
  }

  function test_executeRoleGrants_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrant[] memory grants = _toRoleGrantArray(
      IAaveV4ConfigEngine.RoleGrant({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        executionDelay: 100
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeRoleGrants(grants);
  }

  // ============================================================
  // 2. executeRoleRevocations
  // ============================================================

  function test_executeRoleRevocations_concrete() public {
    IAaveV4ConfigEngine.RoleRevocation[] memory revocations = _toRoleRevocationArray(
      IAaveV4ConfigEngine.RoleRevocation({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit RevokeRoleCalled(5, ACCOUNT);

    engine.executeRoleRevocations(revocations);
  }

  function test_executeRoleRevocations_fuzz(uint64 roleId, address account) public {
    IAaveV4ConfigEngine.RoleRevocation[] memory revocations = _toRoleRevocationArray(
      IAaveV4ConfigEngine.RoleRevocation({
        authority: address(mockAccessManager),
        roleId: roleId,
        account: account
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit RevokeRoleCalled(roleId, account);

    engine.executeRoleRevocations(revocations);
  }

  function test_executeRoleRevocations_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.revokeRole.selector, true);

    IAaveV4ConfigEngine.RoleRevocation[] memory revocations = _toRoleRevocationArray(
      IAaveV4ConfigEngine.RoleRevocation({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeRoleRevocations(revocations);
  }

  // ============================================================
  // 3. executeRoleAdminUpdates
  // ============================================================

  function test_executeRoleAdminUpdates_concrete() public {
    IAaveV4ConfigEngine.RoleAdminUpdate[] memory updates = _toRoleAdminUpdateArray(
      IAaveV4ConfigEngine.RoleAdminUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: 1
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetRoleAdminCalled(5, 1);

    engine.executeRoleAdminUpdates(updates);
  }

  function test_executeRoleAdminUpdates_fuzz(uint64 roleId, uint64 admin) public {
    IAaveV4ConfigEngine.RoleAdminUpdate[] memory updates = _toRoleAdminUpdateArray(
      IAaveV4ConfigEngine.RoleAdminUpdate({
        authority: address(mockAccessManager),
        roleId: roleId,
        admin: admin
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetRoleAdminCalled(roleId, admin);

    engine.executeRoleAdminUpdates(updates);
  }

  function test_executeRoleAdminUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.setRoleAdmin.selector, true);

    IAaveV4ConfigEngine.RoleAdminUpdate[] memory updates = _toRoleAdminUpdateArray(
      IAaveV4ConfigEngine.RoleAdminUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: 1
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeRoleAdminUpdates(updates);
  }

  // ============================================================
  // 4. executeRoleGuardianUpdates
  // ============================================================

  function test_executeRoleGuardianUpdates_concrete() public {
    IAaveV4ConfigEngine.RoleGuardianUpdate[] memory updates = _toRoleGuardianUpdateArray(
      IAaveV4ConfigEngine.RoleGuardianUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        guardian: 2
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetRoleGuardianCalled(5, 2);

    engine.executeRoleGuardianUpdates(updates);
  }

  function test_executeRoleGuardianUpdates_fuzz(uint64 roleId, uint64 guardian) public {
    IAaveV4ConfigEngine.RoleGuardianUpdate[] memory updates = _toRoleGuardianUpdateArray(
      IAaveV4ConfigEngine.RoleGuardianUpdate({
        authority: address(mockAccessManager),
        roleId: roleId,
        guardian: guardian
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetRoleGuardianCalled(roleId, guardian);

    engine.executeRoleGuardianUpdates(updates);
  }

  function test_executeRoleGuardianUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.setRoleGuardian.selector, true);

    IAaveV4ConfigEngine.RoleGuardianUpdate[] memory updates = _toRoleGuardianUpdateArray(
      IAaveV4ConfigEngine.RoleGuardianUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        guardian: 2
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeRoleGuardianUpdates(updates);
  }

  // ============================================================
  // 5. executeTargetFunctionRoleUpdates
  // ============================================================

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

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetTargetFunctionRoleCalled(TARGET, selectors, 5);

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

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetTargetFunctionRoleCalled(target, selectors, roleId);

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

    vm.expectRevert('MOCK_REVERT');
    engine.executeTargetFunctionRoleUpdates(updates);
  }

  // ============================================================
  // 6. executeTargetClosedUpdates
  // ============================================================

  function test_executeTargetClosedUpdates_concrete() public {
    IAaveV4ConfigEngine.TargetClosedUpdate[] memory updates = _toTargetClosedUpdateArray(
      IAaveV4ConfigEngine.TargetClosedUpdate({
        authority: address(mockAccessManager),
        target: TARGET,
        closed: true
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetTargetClosedCalled(TARGET, true);

    engine.executeTargetClosedUpdates(updates);
  }

  function test_executeTargetClosedUpdates_fuzz(address target, bool closed) public {
    IAaveV4ConfigEngine.TargetClosedUpdate[] memory updates = _toTargetClosedUpdateArray(
      IAaveV4ConfigEngine.TargetClosedUpdate({
        authority: address(mockAccessManager),
        target: target,
        closed: closed
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetTargetClosedCalled(target, closed);

    engine.executeTargetClosedUpdates(updates);
  }

  function test_executeTargetClosedUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.setTargetClosed.selector, true);

    IAaveV4ConfigEngine.TargetClosedUpdate[] memory updates = _toTargetClosedUpdateArray(
      IAaveV4ConfigEngine.TargetClosedUpdate({
        authority: address(mockAccessManager),
        target: TARGET,
        closed: true
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeTargetClosedUpdates(updates);
  }

  // ============================================================
  // 7. executeRoleLabelUpdates
  // ============================================================

  function test_executeRoleLabelUpdates_concrete() public {
    IAaveV4ConfigEngine.RoleLabelUpdate[] memory updates = _toRoleLabelUpdateArray(
      IAaveV4ConfigEngine.RoleLabelUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        label: 'FEE_UPDATER'
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit LabelRoleCalled(5, 'FEE_UPDATER');

    engine.executeRoleLabelUpdates(updates);
  }

  function test_executeRoleLabelUpdates_fuzz(uint64 roleId) public {
    string memory label = 'FUZZ_LABEL';

    IAaveV4ConfigEngine.RoleLabelUpdate[] memory updates = _toRoleLabelUpdateArray(
      IAaveV4ConfigEngine.RoleLabelUpdate({
        authority: address(mockAccessManager),
        roleId: roleId,
        label: label
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit LabelRoleCalled(roleId, label);

    engine.executeRoleLabelUpdates(updates);
  }

  function test_executeRoleLabelUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.labelRole.selector, true);

    IAaveV4ConfigEngine.RoleLabelUpdate[] memory updates = _toRoleLabelUpdateArray(
      IAaveV4ConfigEngine.RoleLabelUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        label: 'FEE_UPDATER'
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeRoleLabelUpdates(updates);
  }

  // ============================================================
  // 8. executeGrantDelayUpdates
  // ============================================================

  function test_executeGrantDelayUpdates_concrete() public {
    IAaveV4ConfigEngine.GrantDelayUpdate[] memory updates = _toGrantDelayUpdateArray(
      IAaveV4ConfigEngine.GrantDelayUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        newDelay: 3600
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetGrantDelayCalled(5, 3600);

    engine.executeGrantDelayUpdates(updates);
  }

  function test_executeGrantDelayUpdates_fuzz(uint64 roleId, uint32 newDelay) public {
    IAaveV4ConfigEngine.GrantDelayUpdate[] memory updates = _toGrantDelayUpdateArray(
      IAaveV4ConfigEngine.GrantDelayUpdate({
        authority: address(mockAccessManager),
        roleId: roleId,
        newDelay: newDelay
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetGrantDelayCalled(roleId, newDelay);

    engine.executeGrantDelayUpdates(updates);
  }

  function test_executeGrantDelayUpdates_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.setGrantDelay.selector, true);

    IAaveV4ConfigEngine.GrantDelayUpdate[] memory updates = _toGrantDelayUpdateArray(
      IAaveV4ConfigEngine.GrantDelayUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        newDelay: 3600
      })
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantDelayUpdates(updates);
  }

  // ============================================================
  // 9. executeTargetAdminDelayUpdates
  // ============================================================

  function test_executeTargetAdminDelayUpdates_concrete() public {
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory updates = _toTargetAdminDelayUpdateArray(
      IAaveV4ConfigEngine.TargetAdminDelayUpdate({
        authority: address(mockAccessManager),
        target: TARGET,
        newDelay: 7200
      })
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetTargetAdminDelayCalled(TARGET, 7200);

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

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit SetTargetAdminDelayCalled(target, newDelay);

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

    vm.expectRevert('MOCK_REVERT');
    engine.executeTargetAdminDelayUpdates(updates);
  }

  // ============================================================
  // 10. executeGrantHubConfiguratorFeeUpdaterRole (roleId=5)
  // ============================================================

  function test_executeGrantHubConfiguratorFeeUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorFeeUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorFeeUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorFeeUpdaterRole(grants);
  }

  // ============================================================
  // 11. executeGrantHubConfiguratorReinvestmentUpdaterRole (roleId=6)
  // ============================================================

  function test_executeGrantHubConfiguratorReinvestmentUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(6, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorReinvestmentUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorReinvestmentUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorReinvestmentUpdaterRole(grants);
  }

  // ============================================================
  // 12. executeGrantHubConfiguratorAssetListerRole (roleId=12)
  // ============================================================

  function test_executeGrantHubConfiguratorAssetListerRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(12, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorAssetListerRole(grants);
  }

  function test_executeGrantHubConfiguratorAssetListerRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorAssetListerRole(grants);
  }

  // ============================================================
  // 13. executeGrantHubConfiguratorSpokeAdderRole (roleId=13)
  // ============================================================

  function test_executeGrantHubConfiguratorSpokeAdderRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(13, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorSpokeAdderRole(grants);
  }

  function test_executeGrantHubConfiguratorSpokeAdderRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorSpokeAdderRole(grants);
  }

  // ============================================================
  // 14. executeGrantHubConfiguratorInterestRateUpdaterRole (roleId=11)
  // ============================================================

  function test_executeGrantHubConfiguratorInterestRateUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(11, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorInterestRateUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorInterestRateUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorInterestRateUpdaterRole(grants);
  }

  // ============================================================
  // 15. executeGrantHubConfiguratorHalterRole (roleId=8)
  // ============================================================

  function test_executeGrantHubConfiguratorHalterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(8, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorHalterRole(grants);
  }

  function test_executeGrantHubConfiguratorHalterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorHalterRole(grants);
  }

  // ============================================================
  // 16. executeGrantHubConfiguratorDeactivaterRole (roleId=9)
  // ============================================================

  function test_executeGrantHubConfiguratorDeactivaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(9, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorDeactivaterRole(grants);
  }

  function test_executeGrantHubConfiguratorDeactivaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorDeactivaterRole(grants);
  }

  // ============================================================
  // 17. executeGrantHubConfiguratorCapsUpdaterRole (roleId=10)
  // ============================================================

  function test_executeGrantHubConfiguratorCapsUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(10, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorCapsUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorCapsUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorCapsUpdaterRole(grants);
  }

  // ============================================================
  // 18. executeGrantSpokeConfiguratorAdminRole (roleId=14)
  // ============================================================

  function test_executeGrantSpokeConfiguratorAdminRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(14, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorAdminRole(grants);
  }

  function test_executeGrantSpokeConfiguratorAdminRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantSpokeConfiguratorAdminRole(grants);
  }

  // ============================================================
  // 19. executeGrantSpokeConfiguratorLiquidationUpdaterRole (roleId=15)
  // ============================================================

  function test_executeGrantSpokeConfiguratorLiquidationUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(15, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorLiquidationUpdaterRole(grants);
  }

  function test_executeGrantSpokeConfiguratorLiquidationUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantSpokeConfiguratorLiquidationUpdaterRole(grants);
  }

  // ============================================================
  // 20. executeGrantSpokeConfiguratorReserveAdderRole (roleId=16)
  // ============================================================

  function test_executeGrantSpokeConfiguratorReserveAdderRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(16, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorReserveAdderRole(grants);
  }

  function test_executeGrantSpokeConfiguratorReserveAdderRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantSpokeConfiguratorReserveAdderRole(grants);
  }

  // ============================================================
  // 21. executeGrantSpokeConfiguratorFreezerRole (roleId=17)
  // ============================================================

  function test_executeGrantSpokeConfiguratorFreezerRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(17, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorFreezerRole(grants);
  }

  function test_executeGrantSpokeConfiguratorFreezerRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantSpokeConfiguratorFreezerRole(grants);
  }

  // ============================================================
  // 22. executeGrantSpokeConfiguratorPauserRole (roleId=18)
  // ============================================================

  function test_executeGrantSpokeConfiguratorPauserRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(18, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorPauserRole(grants);
  }

  function test_executeGrantSpokeConfiguratorPauserRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantSpokeConfiguratorPauserRole(grants);
  }

  // ============================================================
  // 23. executeGrantHubConfiguratorAllRoles
  //     Grants 8 roles in order: 5, 6, 12, 13, 11, 8, 9, 10
  // ============================================================

  function test_executeGrantHubConfiguratorAllRoles_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    // Expect 8 events in order: 5, 6, 12, 13, 11, 8, 9, 10
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(5, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(6, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(12, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(13, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(11, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(8, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(9, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(10, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorAllRoles(grants);
  }

  function test_executeGrantHubConfiguratorAllRoles_multiAccount() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray2(
      IAaveV4ConfigEngine.RoleGrantByName({
        authority: address(mockAccessManager),
        account: ACCOUNT
      }),
      IAaveV4ConfigEngine.RoleGrantByName({
        authority: address(mockAccessManager),
        account: ACCOUNT2
      })
    );

    // 16 events total: for each of the 8 roles, grant to ACCOUNT then ACCOUNT2
    // Role 5
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(5, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(5, ACCOUNT2, 0);
    // Role 6
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(6, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(6, ACCOUNT2, 0);
    // Role 12
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(12, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(12, ACCOUNT2, 0);
    // Role 13
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(13, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(13, ACCOUNT2, 0);
    // Role 11
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(11, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(11, ACCOUNT2, 0);
    // Role 8
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(8, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(8, ACCOUNT2, 0);
    // Role 9
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(9, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(9, ACCOUNT2, 0);
    // Role 10
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(10, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(10, ACCOUNT2, 0);

    engine.executeGrantHubConfiguratorAllRoles(grants);
  }

  function test_executeGrantHubConfiguratorAllRoles_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantHubConfiguratorAllRoles(grants);
  }

  // ============================================================
  // 24. executeGrantSpokeConfiguratorAllRoles
  //     Grants 5 roles in order: 14, 15, 16, 17, 18
  // ============================================================

  function test_executeGrantSpokeConfiguratorAllRoles_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    // Expect 5 events in order: 14, 15, 16, 17, 18
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(14, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(15, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(16, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(17, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(18, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorAllRoles(grants);
  }

  function test_executeGrantSpokeConfiguratorAllRoles_multiAccount() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray2(
      IAaveV4ConfigEngine.RoleGrantByName({
        authority: address(mockAccessManager),
        account: ACCOUNT
      }),
      IAaveV4ConfigEngine.RoleGrantByName({
        authority: address(mockAccessManager),
        account: ACCOUNT2
      })
    );

    // 10 events total: for each of the 5 roles, grant to ACCOUNT then ACCOUNT2
    // Role 14
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(14, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(14, ACCOUNT2, 0);
    // Role 15
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(15, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(15, ACCOUNT2, 0);
    // Role 16
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(16, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(16, ACCOUNT2, 0);
    // Role 17
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(17, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(17, ACCOUNT2, 0);
    // Role 18
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(18, ACCOUNT, 0);
    vm.expectEmit(true, true, true, true, address(mockAccessManager));
    emit GrantRoleCalled(18, ACCOUNT2, 0);

    engine.executeGrantSpokeConfiguratorAllRoles(grants);
  }

  function test_executeGrantSpokeConfiguratorAllRoles_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert('MOCK_REVERT');
    engine.executeGrantSpokeConfiguratorAllRoles(grants);
  }
}
