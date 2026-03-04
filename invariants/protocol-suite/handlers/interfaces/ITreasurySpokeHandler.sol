// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title ITreasurySpokeHandler
/// @notice Interface for the TreasurySpokeHandler
interface ITreasurySpokeHandler {
  function supply(uint256 amount, uint8 i, uint8 j) external;

  function withdraw(uint256 amount, uint8 i, uint8 j) external;

  function transfer(uint256 amount, uint8 i, uint8 j, uint8 k) external;
}
