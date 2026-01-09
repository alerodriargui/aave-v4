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
   * @param maxAllowedCollateralReserves_ The maximum allowed number of collateral reserves per user.
   * @param maxAllowedBorrowedReserves_ The maximum allowed number of borrowed reserves per user.
   */
  constructor(
    uint64 spokeRevision_,
    address oracle_,
    uint256 maxAllowedCollateralReserves_,
    uint256 maxAllowedBorrowedReserves_
  ) Spoke(oracle_, maxAllowedCollateralReserves_, maxAllowedBorrowedReserves_) {
    SPOKE_REVISION = spokeRevision_;
    _disableInitializers();
  }

  /// @inheritdoc Spoke
  function initialize(address _authority) external override reinitializer(SPOKE_REVISION) {
    emit UpdateOracle(ORACLE);
    require(_authority != address(0), InvalidAddress());
    _setReservesLimits({
      collateralLimit: MAX_ALLOWED_COLLATERAL_RESERVES,
      borrowedLimit: MAX_ALLOWED_BORROWED_RESERVES
    });
    __AccessManaged_init(_authority);
    if (_liquidationConfig.targetHealthFactor == 0) {
      _liquidationConfig.targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_liquidationConfig);
    }
  }
}
