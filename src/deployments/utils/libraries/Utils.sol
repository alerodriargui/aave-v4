// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

library Utils {
  function computeCreateAddress(address deployer, uint8 nonce) internal pure returns (address) {
    // RLP([deployer, nonce]) for 0 <= nonce <= 0x7f
    // nonce == 0 is encoded as the empty string (0x80) in RLP
    require(nonce < 0x80, 'Utils: nonce >= 0x80 not supported');
    bytes1 nonceRlp = nonce == 0 ? bytes1(0x80) : bytes1(nonce);
    bytes memory rlp = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, nonceRlp);
    return address(uint160(uint256(keccak256(rlp))));
  }
}
