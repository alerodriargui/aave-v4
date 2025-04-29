// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ITreasurySpoke {
  error InvalidHubAddress(); // todo: this is duplicated

  function supply(uint256 assetId, uint256 amount) external;

  function withdraw(uint256 assetId, uint256 amount, address to) external;

  function getSuppliedAmount(uint256 assetId) external view returns (uint256);

  function gerSuppliedShares(uint256 assetId) external view returns (uint256);
}
