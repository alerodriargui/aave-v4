// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IHubConfiguratorHandler
/// @notice Interface for the HubConfiguratorHandler
interface IHubConfiguratorHandler {
  function updateSpokeSupplyCap(uint256 addCap, uint8 i, uint8 j) external;

  function updateSpokeDrawCap(uint256 drawCap, uint8 i, uint8 j) external;

  function updateSpokeRiskPremiumThreshold(uint256 riskPremiumThreshold, uint8 i, uint8 j) external;

  function updateSpokeHalted(bool halted, uint8 i, uint8 j) external;

  function updateLiquidityFee(uint256 liquidityFee, uint8 i) external;
}
