// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';

/// @title IAccessManagerEngine
/// @author Aave Labs
/// @notice Interface for the Access Manager Engine contract.
interface IAccessManagerEngine {
  function executeRoleMemberships(
    IAaveV4ConfigEngine.RoleMembership[] calldata memberships
  ) external;
  function executeRoleUpdates(IAaveV4ConfigEngine.RoleUpdate[] calldata updates) external;
  function executeTargetFunctionRoleUpdates(
    IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] calldata updates
  ) external;
  function executeTargetAdminDelayUpdates(
    IAaveV4ConfigEngine.TargetAdminDelayUpdate[] calldata updates
  ) external;
}
