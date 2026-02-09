// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {RiskFreeLiquidationLogic} from 'src/spoke/libraries/RiskFreeLiquidationLogic.sol';
import {RiskFreeSpoke} from 'src/spoke/RiskFreeSpoke.sol';

/// @title RiskFreeSpokeInstance
/// @author Aave Labs
/// @notice Implementation contract for RiskFreeSpoke (no premium calculations).
/// @dev Debt is simply drawnShares.toAssets() without any premium calculations.
contract RiskFreeSpokeInstance is RiskFreeSpoke {
  uint64 public constant SPOKE_REVISION = 1;

  /// @dev Constructor.
  /// @dev During upgrade, must ensure that the new oracle is supporting existing assets on the spoke and the replaced oracle.
  /// @param oracle_ The address of the oracle.
  constructor(address oracle_) RiskFreeSpoke(oracle_) {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @dev The authority contract must implement the `AccessManaged` interface for access control.
  /// @param authority The address of the authority contract which manages permissions.
  function initialize(address authority) external override reinitializer(SPOKE_REVISION) {
    emit UpdateOracle(ORACLE);
    require(authority != address(0), InvalidAddress());
    __AccessManaged_init(authority);
    if (_getSpokeStorage()._liquidationConfig.targetHealthFactor == 0) {
      _getSpokeStorage()
        ._liquidationConfig
        .targetHealthFactor = HEALTH_FACTOR_LIQUIDATION_THRESHOLD;
      emit UpdateLiquidationConfig(_getSpokeStorage()._liquidationConfig);
    }
  }
}
