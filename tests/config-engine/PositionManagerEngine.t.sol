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

  function test_executePositionManagerRescues_tokenOnly() public {
    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: TOKEN,
        to: RESCUE_TO,
        tokenAmount: RESCUE_AMOUNT,
        nativeAmount: 0
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueTokenCalled(TOKEN, RESCUE_TO, RESCUE_AMOUNT);

    engine.executePositionManagerRescues(rescues);
  }

  function test_executePositionManagerRescues_nativeOnly() public {
    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: address(0),
        to: RESCUE_TO,
        tokenAmount: 0,
        nativeAmount: RESCUE_AMOUNT
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueNativeCalled(RESCUE_TO, RESCUE_AMOUNT);

    engine.executePositionManagerRescues(rescues);
  }

  function test_executePositionManagerRescues_both() public {
    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: TOKEN,
        to: RESCUE_TO,
        tokenAmount: RESCUE_AMOUNT,
        nativeAmount: RESCUE_AMOUNT
      })
    );

    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueTokenCalled(TOKEN, RESCUE_TO, RESCUE_AMOUNT);
    vm.expectEmit(address(mockPositionManager));
    emit MockPositionManagerForEngine.RescueNativeCalled(RESCUE_TO, RESCUE_AMOUNT);

    engine.executePositionManagerRescues(rescues);
  }

  function test_executePositionManagerRescues_skipBoth() public {
    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: address(0),
        to: RESCUE_TO,
        tokenAmount: 0,
        nativeAmount: 0
      })
    );

    vm.recordLogs();
    engine.executePositionManagerRescues(rescues);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function testFuzz_executePositionManagerRescues(
    address token,
    address to,
    uint256 tokenAmount,
    uint256 nativeAmount
  ) public {
    vm.assume(tokenAmount > 0 || nativeAmount > 0);

    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: token,
        to: to,
        tokenAmount: tokenAmount,
        nativeAmount: nativeAmount
      })
    );

    if (tokenAmount > 0) {
      vm.expectEmit(address(mockPositionManager));
      emit MockPositionManagerForEngine.RescueTokenCalled(token, to, tokenAmount);
    }
    if (nativeAmount > 0) {
      vm.expectEmit(address(mockPositionManager));
      emit MockPositionManagerForEngine.RescueNativeCalled(to, nativeAmount);
    }

    engine.executePositionManagerRescues(rescues);
  }

  function test_executePositionManagerRescues_revert_token() public {
    mockPositionManager.setShouldRevert(IRescuable.rescueToken.selector, true);

    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: TOKEN,
        to: RESCUE_TO,
        tokenAmount: RESCUE_AMOUNT,
        nativeAmount: 0
      })
    );

    vm.expectRevert(MockPositionManagerForEngine.RescueTokenReverted.selector);
    engine.executePositionManagerRescues(rescues);
  }

  function test_executePositionManagerRescues_revert_native() public {
    mockPositionManager.setShouldRevert(IRescuable.rescueNative.selector, true);

    IAaveV4ConfigEngine.Rescue[] memory rescues = _toRescueArray(
      IAaveV4ConfigEngine.Rescue({
        positionManager: address(mockPositionManager),
        token: address(0),
        to: RESCUE_TO,
        tokenAmount: 0,
        nativeAmount: RESCUE_AMOUNT
      })
    );

    vm.expectRevert(MockPositionManagerForEngine.RescueNativeReverted.selector);
    engine.executePositionManagerRescues(rescues);
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
