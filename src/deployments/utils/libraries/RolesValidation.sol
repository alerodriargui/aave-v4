// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title RolesValidation Library
/// @author Aave Labs
/// @notice Validation helpers for role setup procedures.
library RolesValidation {
  /// @notice Reverts if the address is zero.
  function validateNonZeroAddress(address addr) internal pure {
    require(addr != address(0), 'zero address');
  }
}
