// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title IPositionManagerEngine
/// @author Aave Labs
/// @notice Interface for the Position Manager Engine contract.
interface IPositionManagerEngine {
  function executePositionManagerSpokeRegistrations(
    IAaveV4ConfigEngine.SpokeRegistration[] calldata registrations
  ) external;
  function executePositionManagerRescues(IAaveV4ConfigEngine.Rescue[] calldata rescues) external;
  function executePositionManagerRoleRenouncements(
    IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] calldata renouncements
  ) external;
}
