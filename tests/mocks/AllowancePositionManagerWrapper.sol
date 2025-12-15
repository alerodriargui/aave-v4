// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {TransientSlot} from 'src/dependencies/openzeppelin/TransientSlot.sol';
import {AllowancePositionManager} from 'src/position-manager/AllowancePositionManager.sol';

contract AllowancePositionManagerWrapper is AllowancePositionManager {
  using TransientSlot for *;

  constructor(address spoke_) AllowancePositionManager(spoke_) {}

  function temporaryWithdrawAllowance(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256) {
    return _temporaryWithdrawAllowancesSlot(owner, spender, reserveId).tload();
  }

  function temporaryCreditDelegation(
    address owner,
    address spender,
    uint256 reserveId
  ) external view returns (uint256) {
    return _temporaryCreditDelegationsSlot(owner, spender, reserveId).tload();
  }
}
