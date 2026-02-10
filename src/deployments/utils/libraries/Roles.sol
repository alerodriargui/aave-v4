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
}
