// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice Echidna-compatible mock of the Safe Singleton Factory (0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7).
/// Replicates the same calldata format: salt (32 bytes) ++ initcode, returns 20-byte deployed address.
contract MockCreate2Factory {
  fallback() external payable {
    assembly {
      let size := sub(calldatasize(), 32)
      calldatacopy(0, 32, size)
      let addr := create2(callvalue(), 0, size, calldataload(0))
      if iszero(addr) {
        revert(0, 0)
      }
      mstore(0, addr)
      return(12, 20)
    }
  }
}
