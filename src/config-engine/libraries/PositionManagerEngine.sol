// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {IRescuable} from 'src/interfaces/IRescuable.sol';

/// @title PositionManagerEngine
/// @author Aave Labs
/// @notice Library containing position manager logic for AaveV4ConfigEngine.
library PositionManagerEngine {
  /// @notice Registers/deregisters spokes on position managers.
  /// @param registrations The spoke registrations to execute.
  function executePositionManagerSpokeRegistrations(
    IAaveV4ConfigEngine.SpokeRegistration[] calldata registrations
  ) external {
    uint256 length = registrations.length;
    for (uint256 i; i < length; ++i) {
      IPositionManagerBase(registrations[i].positionManager).registerSpoke(
        registrations[i].spoke,
        registrations[i].registered
      );
    }
  }

  /// @notice Rescues ERC20 tokens from position managers.
  /// @param rescues The token rescues to execute.
  function executePositionManagerTokenRescues(
    IAaveV4ConfigEngine.TokenRescue[] calldata rescues
  ) external {
    uint256 length = rescues.length;
    for (uint256 i; i < length; ++i) {
      IRescuable(rescues[i].positionManager).rescueToken(
        rescues[i].token,
        rescues[i].to,
        rescues[i].amount
      );
    }
  }

  /// @notice Rescues native assets from position managers.
  /// @param rescues The native rescues to execute.
  function executePositionManagerNativeRescues(
    IAaveV4ConfigEngine.NativeRescue[] calldata rescues
  ) external {
    uint256 length = rescues.length;
    for (uint256 i; i < length; ++i) {
      IRescuable(rescues[i].positionManager).rescueNative(rescues[i].to, rescues[i].amount);
    }
  }

  /// @notice Renounces position manager roles for users on spokes.
  /// @param renouncements The role renouncements to execute.
  function executePositionManagerRoleRenouncements(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] calldata renouncements
  ) external {
    uint256 length = renouncements.length;
    for (uint256 i; i < length; ++i) {
      IPositionManagerBase(renouncements[i].positionManager).renouncePositionManagerRole(
        renouncements[i].spoke,
        renouncements[i].user
      );
    }
  }
}
