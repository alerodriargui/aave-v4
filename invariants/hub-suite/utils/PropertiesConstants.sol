// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Vm} from 'forge-std/Base.sol';

/// @notice Testing constants and properties for hub-focused invariant suite
abstract contract PropertiesConstants {
  /// @dev Cheat code address
  address internal constant VM_ADDRESS = address(uint160(uint256(keccak256('hevm cheat code'))));

  /// @dev Virtual machine instance
  Vm internal constant vm = Vm(VM_ADDRESS);

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                   HUB PROPERTY STRINGS                                    //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  // Hub Invariants
  string internal constant HUB_INV_LIQUIDITY = 'HUB_INV: Liquidity accounting mismatch';
  string internal constant HUB_INV_SHARES = 'HUB_INV: Share calculation error';
  string internal constant HUB_INV_INTEREST = 'HUB_INV: Interest accrual mismatch';
  string internal constant HUB_INV_DEFICIT = 'HUB_INV: Deficit tracking error';

  // Hub Postconditions
  string internal constant HUB_POST_SUPPLY = 'HUB_POST: Supply state invalid';
  string internal constant HUB_POST_DRAW = 'HUB_POST: Draw state invalid';
  string internal constant HUB_POST_REPAY = 'HUB_POST: Repay state invalid';
  string internal constant HUB_POST_CAP = 'HUB_POST: Cap constraint violated';
}
