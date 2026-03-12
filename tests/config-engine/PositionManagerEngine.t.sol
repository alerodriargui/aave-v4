// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {MockPositionManager} from 'tests/mocks/config-engine/MockPositionManager.sol';

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
    emit MockPositionManager.RegisterSpokeCalled(SPOKE, true);

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
    emit MockPositionManager.RegisterSpokeCalled(spoke, registered);

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

    vm.expectRevert(MockPositionManager.RegisterSpokeReverted.selector);
    engine.executePositionManagerSpokeRegistrations(regs);
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
    emit MockPositionManager.RenouncePositionManagerRoleCalled(SPOKE, USER);

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
    emit MockPositionManager.RenouncePositionManagerRoleCalled(spoke, user);

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

    vm.expectRevert(MockPositionManager.RenouncePositionManagerRoleReverted.selector);
    engine.executePositionManagerRoleRenouncements(renouncements);
  }
}
