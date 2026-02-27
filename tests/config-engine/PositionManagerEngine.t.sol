// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IRescuable} from 'src/interfaces/IRescuable.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {MockPositionManagerForEngine} from 'tests/mocks/config-engine/MockPositionManagerForEngine.sol';

contract PositionManagerEngineTest is BaseConfigEngineTest {
  function test_executePositionManagerSpokeRegistrations_concrete() public {
    IAaveV4ConfigEngine.SpokeRegistration[] memory regs = _toSpokeRegistrationArray(
      IAaveV4ConfigEngine.SpokeRegistration({
        positionManager: address(mockPositionManager),
        spoke: SPOKE,
        registered: true
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RegisterSpokeCalled(SPOKE, true);

    engine.executePositionManagerSpokeRegistrations(regs);
  }

  function test_executePositionManagerSpokeRegistrations_fuzz(
    address spoke,
    bool registered
  ) public {
    IAaveV4ConfigEngine.SpokeRegistration[] memory regs = _toSpokeRegistrationArray(
      IAaveV4ConfigEngine.SpokeRegistration({
        positionManager: address(mockPositionManager),
        spoke: spoke,
        registered: registered
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RegisterSpokeCalled(spoke, registered);

    engine.executePositionManagerSpokeRegistrations(regs);
  }

  function test_executePositionManagerSpokeRegistrations_revert() public {
    mockPositionManager.setShouldRevert(IPositionManagerBase.registerSpoke.selector, true);

    IAaveV4ConfigEngine.SpokeRegistration[] memory regs = _toSpokeRegistrationArray(
      IAaveV4ConfigEngine.SpokeRegistration({
        positionManager: address(mockPositionManager),
        spoke: SPOKE,
        registered: true
      })
    );

    vm.expectRevert(MockPositionManagerForEngine.RegisterSpokeReverted.selector);
    engine.executePositionManagerSpokeRegistrations(regs);
  }

  function test_executePositionManagerTokenRescues_concrete() public {
    IAaveV4ConfigEngine.TokenRescue[] memory rescues = _toTokenRescueArray(
      IAaveV4ConfigEngine.TokenRescue({
        positionManager: address(mockPositionManager),
        token: TOKEN,
        to: RESCUE_TO,
        amount: RESCUE_AMOUNT
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueTokenCalled(TOKEN, RESCUE_TO, RESCUE_AMOUNT);

    engine.executePositionManagerTokenRescues(rescues);
  }

  function test_executePositionManagerTokenRescues_fuzz(
    address token,
    address to,
    uint256 amount
  ) public {
    IAaveV4ConfigEngine.TokenRescue[] memory rescues = _toTokenRescueArray(
      IAaveV4ConfigEngine.TokenRescue({
        positionManager: address(mockPositionManager),
        token: token,
        to: to,
        amount: amount
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueTokenCalled(token, to, amount);

    engine.executePositionManagerTokenRescues(rescues);
  }

  function test_executePositionManagerTokenRescues_revert() public {
    mockPositionManager.setShouldRevert(IRescuable.rescueToken.selector, true);

    IAaveV4ConfigEngine.TokenRescue[] memory rescues = _toTokenRescueArray(
      IAaveV4ConfigEngine.TokenRescue({
        positionManager: address(mockPositionManager),
        token: TOKEN,
        to: RESCUE_TO,
        amount: RESCUE_AMOUNT
      })
    );

    vm.expectRevert(MockPositionManagerForEngine.RescueTokenReverted.selector);
    engine.executePositionManagerTokenRescues(rescues);
  }

  function test_executePositionManagerNativeRescues_concrete() public {
    IAaveV4ConfigEngine.NativeRescue[] memory rescues = _toNativeRescueArray(
      IAaveV4ConfigEngine.NativeRescue({
        positionManager: address(mockPositionManager),
        to: RESCUE_TO,
        amount: RESCUE_AMOUNT
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueNativeCalled(RESCUE_TO, RESCUE_AMOUNT);

    engine.executePositionManagerNativeRescues(rescues);
  }

  function test_executePositionManagerNativeRescues_fuzz(address to, uint256 amount) public {
    IAaveV4ConfigEngine.NativeRescue[] memory rescues = _toNativeRescueArray(
      IAaveV4ConfigEngine.NativeRescue({
        positionManager: address(mockPositionManager),
        to: to,
        amount: amount
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueNativeCalled(to, amount);

    engine.executePositionManagerNativeRescues(rescues);
  }

  function test_executePositionManagerNativeRescues_revert() public {
    mockPositionManager.setShouldRevert(IRescuable.rescueNative.selector, true);

    IAaveV4ConfigEngine.NativeRescue[] memory rescues = _toNativeRescueArray(
      IAaveV4ConfigEngine.NativeRescue({
        positionManager: address(mockPositionManager),
        to: RESCUE_TO,
        amount: RESCUE_AMOUNT
      })
    );

    vm.expectRevert(MockPositionManagerForEngine.RescueNativeReverted.selector);
    engine.executePositionManagerNativeRescues(rescues);
  }

  function test_executePositionManagerRoleRenouncements_concrete() public {
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = _toPositionManagerRoleRenouncementArray(
        IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
          positionManager: address(mockPositionManager),
          spoke: SPOKE,
          user: USER
        })
      );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RenouncePositionManagerRoleCalled(SPOKE, USER);

    engine.executePositionManagerRoleRenouncements(renouncements);
  }

  function test_executePositionManagerRoleRenouncements_fuzz(address spoke, address user) public {
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = _toPositionManagerRoleRenouncementArray(
        IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
          positionManager: address(mockPositionManager),
          spoke: spoke,
          user: user
        })
      );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RenouncePositionManagerRoleCalled(spoke, user);

    engine.executePositionManagerRoleRenouncements(renouncements);
  }

  function test_executePositionManagerRoleRenouncements_revert() public {
    mockPositionManager.setShouldRevert(
      IPositionManagerBase.renouncePositionManagerRole.selector,
      true
    );

    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[]
      memory renouncements = _toPositionManagerRoleRenouncementArray(
        IAaveV4ConfigEngine.PositionManagerRoleRenouncement({
          positionManager: address(mockPositionManager),
          spoke: SPOKE,
          user: USER
        })
      );

    vm.expectRevert(MockPositionManagerForEngine.RenouncePositionManagerRoleReverted.selector);
    engine.executePositionManagerRoleRenouncements(renouncements);
  }
}
