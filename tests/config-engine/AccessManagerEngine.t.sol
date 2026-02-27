// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {MockAccessManagerForEngine} from 'tests/mocks/config-engine/MockAccessManagerForEngine.sol';

contract AccessManagerEngineTest is BaseConfigEngineTest {
  // Secondary account for multi-account tests
  address constant ACCOUNT2 = address(0x7002);

  function test_executeRoleGrants_concrete() public {
    IAaveV4ConfigEngine.RoleGrant[] memory grants = _toRoleGrantArray(
      IAaveV4ConfigEngine.RoleGrant({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT,
        executionDelay: 100
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 100);

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(roleId, account, executionDelay);

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

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeRoleGrants(grants);
  }

  function test_executeRoleRevocations_concrete() public {
    IAaveV4ConfigEngine.RoleRevocation[] memory revocations = _toRoleRevocationArray(
      IAaveV4ConfigEngine.RoleRevocation({
        authority: address(mockAccessManager),
        roleId: 5,
        account: ACCOUNT
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.RevokeRoleCalled(5, ACCOUNT);

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.RevokeRoleCalled(roleId, account);

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

    vm.expectRevert(MockAccessManagerForEngine.RevokeRoleReverted.selector);
    engine.executeRoleRevocations(revocations);
  }

  function test_executeRoleAdminUpdates_concrete() public {
    IAaveV4ConfigEngine.RoleAdminUpdate[] memory updates = _toRoleAdminUpdateArray(
      IAaveV4ConfigEngine.RoleAdminUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        admin: 1
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetRoleAdminCalled(5, 1);

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetRoleAdminCalled(roleId, admin);

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

    vm.expectRevert(MockAccessManagerForEngine.SetRoleAdminReverted.selector);
    engine.executeRoleAdminUpdates(updates);
  }

  function test_executeRoleGuardianUpdates_concrete() public {
    IAaveV4ConfigEngine.RoleGuardianUpdate[] memory updates = _toRoleGuardianUpdateArray(
      IAaveV4ConfigEngine.RoleGuardianUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        guardian: 2
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetRoleGuardianCalled(5, 2);

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetRoleGuardianCalled(roleId, guardian);

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

    vm.expectRevert(MockAccessManagerForEngine.SetRoleGuardianReverted.selector);
    engine.executeRoleGuardianUpdates(updates);
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
    emit MockAccessManagerForEngine.SetTargetFunctionRoleCalled(TARGET, selectors, 5);

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
    emit MockAccessManagerForEngine.SetTargetFunctionRoleCalled(target, selectors, roleId);

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

    vm.expectRevert(MockAccessManagerForEngine.SetTargetFunctionRoleReverted.selector);
    engine.executeTargetFunctionRoleUpdates(updates);
  }

  function test_executeTargetClosedUpdates_concrete() public {
    IAaveV4ConfigEngine.TargetClosedUpdate[] memory updates = _toTargetClosedUpdateArray(
      IAaveV4ConfigEngine.TargetClosedUpdate({
        authority: address(mockAccessManager),
        target: TARGET,
        closed: true
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetTargetClosedCalled(TARGET, true);

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetTargetClosedCalled(target, closed);

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

    vm.expectRevert(MockAccessManagerForEngine.SetTargetClosedReverted.selector);
    engine.executeTargetClosedUpdates(updates);
  }

  function test_executeRoleLabelUpdates_concrete() public {
    IAaveV4ConfigEngine.RoleLabelUpdate[] memory updates = _toRoleLabelUpdateArray(
      IAaveV4ConfigEngine.RoleLabelUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        label: 'FEE_UPDATER'
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.LabelRoleCalled(5, 'FEE_UPDATER');

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.LabelRoleCalled(roleId, label);

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

    vm.expectRevert(MockAccessManagerForEngine.LabelRoleReverted.selector);
    engine.executeRoleLabelUpdates(updates);
  }

  function test_executeGrantDelayUpdates_concrete() public {
    IAaveV4ConfigEngine.GrantDelayUpdate[] memory updates = _toGrantDelayUpdateArray(
      IAaveV4ConfigEngine.GrantDelayUpdate({
        authority: address(mockAccessManager),
        roleId: 5,
        newDelay: 3600
      })
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetGrantDelayCalled(5, 3600);

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

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.SetGrantDelayCalled(roleId, newDelay);

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

    vm.expectRevert(MockAccessManagerForEngine.SetGrantDelayReverted.selector);
    engine.executeGrantDelayUpdates(updates);
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
    emit MockAccessManagerForEngine.SetTargetAdminDelayCalled(TARGET, 7200);

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
    emit MockAccessManagerForEngine.SetTargetAdminDelayCalled(target, newDelay);

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

    vm.expectRevert(MockAccessManagerForEngine.SetTargetAdminDelayReverted.selector);
    engine.executeTargetAdminDelayUpdates(updates);
  }

  function test_executeGrantHubConfiguratorFeeUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorFeeUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorFeeUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorFeeUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorReinvestmentUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorReinvestmentUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorReinvestmentUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorReinvestmentUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorAssetListerRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorAssetListerRole(grants);
  }

  function test_executeGrantHubConfiguratorAssetListerRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorAssetListerRole(grants);
  }

  function test_executeGrantHubConfiguratorSpokeAdderRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorSpokeAdderRole(grants);
  }

  function test_executeGrantHubConfiguratorSpokeAdderRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorSpokeAdderRole(grants);
  }

  function test_executeGrantHubConfiguratorInterestRateUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorInterestRateUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorInterestRateUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorInterestRateUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorHalterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorHalterRole(grants);
  }

  function test_executeGrantHubConfiguratorHalterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorHalterRole(grants);
  }

  function test_executeGrantHubConfiguratorDeactivaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorDeactivaterRole(grants);
  }

  function test_executeGrantHubConfiguratorDeactivaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorDeactivaterRole(grants);
  }

  function test_executeGrantHubConfiguratorCapsUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorCapsUpdaterRole(grants);
  }

  function test_executeGrantHubConfiguratorCapsUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorCapsUpdaterRole(grants);
  }

  function test_executeGrantSpokeConfiguratorAdminRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorAdminRole(grants);
  }

  function test_executeGrantSpokeConfiguratorAdminRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantSpokeConfiguratorAdminRole(grants);
  }

  function test_executeGrantSpokeConfiguratorLiquidationUpdaterRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorLiquidationUpdaterRole(grants);
  }

  function test_executeGrantSpokeConfiguratorLiquidationUpdaterRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantSpokeConfiguratorLiquidationUpdaterRole(grants);
  }

  function test_executeGrantSpokeConfiguratorReserveAdderRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorReserveAdderRole(grants);
  }

  function test_executeGrantSpokeConfiguratorReserveAdderRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantSpokeConfiguratorReserveAdderRole(grants);
  }

  function test_executeGrantSpokeConfiguratorFreezerRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorFreezerRole(grants);
  }

  function test_executeGrantSpokeConfiguratorFreezerRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantSpokeConfiguratorFreezerRole(grants);
  }

  function test_executeGrantSpokeConfiguratorPauserRole_concrete() public {
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorPauserRole(grants);
  }

  function test_executeGrantSpokeConfiguratorPauserRole_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantSpokeConfiguratorPauserRole(grants);
  }

  function test_executeGrantHubConfiguratorAllRoles_concrete() public {
    // AllRoles now maps to a single HUB_CONFIGURATOR_ROLE (4) grant per account
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);

    engine.executeGrantHubConfiguratorAllRoles(grants);
  }

  function test_executeGrantHubConfiguratorAllRoles_multiAccount() public {
    // AllRoles now maps to a single HUB_CONFIGURATOR_ROLE (4) grant per account
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

    // 2 events total: grant role 4 to ACCOUNT then ACCOUNT2
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT, 0);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(4, ACCOUNT2, 0);

    engine.executeGrantHubConfiguratorAllRoles(grants);
  }

  function test_executeGrantHubConfiguratorAllRoles_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantHubConfiguratorAllRoles(grants);
  }

  function test_executeGrantSpokeConfiguratorAllRoles_concrete() public {
    // AllRoles now maps to a single SPOKE_CONFIGURATOR_ROLE (5) grant per account
    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);

    engine.executeGrantSpokeConfiguratorAllRoles(grants);
  }

  function test_executeGrantSpokeConfiguratorAllRoles_multiAccount() public {
    // AllRoles now maps to a single SPOKE_CONFIGURATOR_ROLE (5) grant per account
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

    // 2 events total: grant role 5 to ACCOUNT then ACCOUNT2
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT, 0);
    vm.expectEmit(address(mockAccessManager));
    emit MockAccessManagerForEngine.GrantRoleCalled(5, ACCOUNT2, 0);

    engine.executeGrantSpokeConfiguratorAllRoles(grants);
  }

  function test_executeGrantSpokeConfiguratorAllRoles_revert() public {
    mockAccessManager.setShouldRevert(IAccessManager.grantRole.selector, true);

    IAaveV4ConfigEngine.RoleGrantByName[] memory grants = _toRoleGrantByNameArray(
      _defaultRoleGrantByName()
    );

    vm.expectRevert(MockAccessManagerForEngine.GrantRoleReverted.selector);
    engine.executeGrantSpokeConfiguratorAllRoles(grants);
  }
}
