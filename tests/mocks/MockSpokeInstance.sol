// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Spoke} from 'src/spoke/Spoke.sol';

contract MockSpokeInstance is Spoke {
  bool public constant IS_TEST = true;

  uint64 public immutable SPOKE_REVISION;

  /**
   * @dev Constructor.
   * @dev It sets the spoke revision and disables the initializers.
   * @param spokeRevision_ The revision of the spoke contract.
   * @param oracle_ The address of the oracle.
   */
  constructor(uint64 spokeRevision_, address oracle_) Spoke(oracle_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc Spoke
  function initialize(
    address authority,
    uint64 maxUserCollaterals,
    uint64 maxUserBorrows
  ) external override reinitializer(SPOKE_REVISION) {
    emit UpdateOracle(ORACLE);
    require(authority != address(0), InvalidAddress());
    _setUserReservesLimits(maxUserCollaterals, maxUserBorrows);
    __AccessManaged_init(authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
