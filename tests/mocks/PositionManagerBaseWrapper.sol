// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {PositionManagerBase} from 'src/position-manager/PositionManagerBase.sol';

contract PositionManagerBaseWrapper is PositionManagerBase {
  constructor(address spoke_) PositionManagerBase(spoke_) {}

  function getReserveUnderlying(uint256 reserveId) external view returns (address) {
    return address(_getReserveUnderlying(reserveId));
  }
}
