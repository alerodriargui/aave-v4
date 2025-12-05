// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;
interface IProgressLogger {
  function log(string memory label, address value) external pure;

  function log(string memory label, uint256 value) external pure;

  function log(string memory value) external pure;
}
