// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library Utils {
  function computeCreateAddress(address deployer, uint8 nonce) internal pure returns (address) {
    // RLP([deployer, nonce]) for 1 <= nonce <= 0x7f
    bytes memory rlp = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, nonce);
    return address(uint160(uint256(keccak256(rlp))));
  }
}
