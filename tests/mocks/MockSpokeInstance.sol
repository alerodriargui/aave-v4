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
   * @param maxUserCollaterals_ The maximum allowed number of collateral reserves per user.
   * @param maxUserBorrows_ The maximum allowed number of borrowed reserves per user.
   */
  constructor(
    uint64 spokeRevision_,
    address oracle_,
    uint64 maxUserCollaterals_,
    uint64 maxUserBorrows_
  ) Spoke(oracle_, maxUserCollaterals_, maxUserBorrows_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc Spoke
  function initialize(address _authority) external override reinitializer(SPOKE_REVISION) {
    emit UpdateOracle(ORACLE);
    require(_authority != address(0), InvalidAddress());
    _setUserReservesLimits(MAX_USER_COLLATERALS, MAX_USER_BORROWS);
    __AccessManaged_init(_authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
