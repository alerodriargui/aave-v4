// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {LiquidationLogic} from 'src/spoke/libraries/LiquidationLogic.sol';
import {Spoke} from 'src/spoke/Spoke.sol';

/// @title SpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for the Spoke.
contract SpokeInstance is Spoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @dev Constructor.
  /// @dev During upgrade, must ensure that the new oracle is supporting existing assets on the spoke and the replaced oracle.
  /// @param oracle_ The address of the oracle.
  constructor(address oracle_) Spoke(oracle_) {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  /// @param maxUserCollaterals The maximum allowed number of collateral reserves per user.
  /// @param maxUserBorrows The maximum allowed number of borrowed reserves per user.
  function initialize(
    address authority,
    uint24 maxUserCollaterals,
    uint24 maxUserBorrows
  ) external override reinitializer(SPOKE_REVISION) {
    emit UpdateOracle(ORACLE);
    require(authority != address(0), InvalidAddress());
    _setUserReserveLimits(maxUserCollaterals, maxUserBorrows);
    __AccessManaged_init(authority);
    if (_spokeConfig.targetHealthFactor == 0) {
      _spokeConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateSpokeConfig(_spokeConfig);
    }
  }
}
