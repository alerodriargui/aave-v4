// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

library EIP712Types {
  struct SetUserPositionManager {
    address positionManager;
    address user;
    bool approve;
    uint256 nonce;
    uint256 deadline;
  }

  struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
  }
}
