// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

/// @title Roles library
/// @author Aave Labs
/// @notice Defines the different roles used by the protocol.
library Roles {
  uint64 public constant DEFAULT_ADMIN_ROLE = 0;
  uint64 public constant HUB_ADMIN_ROLE = 1;
  uint64 public constant SPOKE_ADMIN_ROLE = 2;
  uint64 public constant USER_POSITION_UPDATER_ROLE = 3;
  uint64 public constant HUB_FEE_MINTER_ROLE = 4;
  uint64 public constant HUB_CONFIGURATOR_ROLE = 5;
  uint64 public constant SPOKE_CONFIGURATOR_ROLE = 6;
  uint64 public constant SPOKE_POSITION_UPDATER_ROLE = 7;
  uint64 public constant DEFICIT_ELIMINATOR_ROLE = 8;
  // HubConfigurator roles
  uint64 public constant HUB_CONFIGURATOR_ADMIN_ROLE = 9;
  uint64 public constant HUB_HALT_ROLE = 10;
  uint64 public constant HUB_DEACTIVATE_ROLE = 11;
  uint64 public constant HUB_CAPS_RESET_ROLE = 12;
  // SpokeConfigurator roles
  uint64 public constant SPOKE_CONFIGURATOR_ADMIN_ROLE = 13;
  uint64 public constant SPOKE_FREEZE_ROLE = 14;
  uint64 public constant SPOKE_PAUSE_ROLE = 15;
}
