// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title IHubConfiguratorHandler
/// @notice Interface for the HubConfiguratorHandler
interface IHubConfiguratorHandler {
  function updateSpokeSupplyCap(uint256 addCap, uint8 i, uint8 j, uint8 k) external;

  function updateSpokeDrawCap(uint256 drawCap, uint8 i, uint8 j, uint8 k) external;

  function updateSpokeRiskPremiumThreshold(
    uint256 riskPremiumThreshold,
    uint8 i,
    uint8 j,
    uint8 k
  ) external;

  function updateSpokeHalted(bool halted, uint8 i, uint8 j, uint8 k) external;
}
