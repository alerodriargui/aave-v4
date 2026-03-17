// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

contract InputUtils {
  /// @dev Full deploy inputs for deploying the entire Aave V4 protocol.
  /// @dev accessManagerAdmin The default admin of the access manager.
  /// @dev hubAdmin The admin of the hub.
  /// @dev hubConfiguratorAdmin The admin granted all hub configurator roles.
  /// @dev treasurySpokeOwner The owner of the treasury spoke.
  /// @dev spokeAdmin The spoke admin.
  /// @dev spokeProxyAdminOwner The owner of the spoke proxyAdmin.
  /// @dev spokeConfiguratorAdmin The admin granted all spoke configurator roles.
  /// @dev gatewayOwner The owner of the native token and signature gateways.
  /// @dev positionManagerOwner The owner of the position manager contracts (giver/taker).
  /// @dev nativeWrapper The address of the native wrapper (required when deployNativeTokenGateway is true).
  /// @dev deployNativeTokenGateway Whether to deploy the NativeTokenGateway (from periphery config).
  /// @dev deploySignatureGateway Whether to deploy the SignatureGateway (from periphery config).
  /// @dev deployPositionManagers Whether to deploy the position manager batch (giver/taker).
  /// @dev grantRoles A boolean indicating if roles should be granted.
  /// @dev hubLabels An array of hub labels; the number of hub labels defines the number of hubs to deploy.
  /// @dev spokeLabels An array of spoke labels; the number of spoke labels defines the number of spokes to deploy.
  /// @dev spokeMaxReservesLimits Per-spoke max user reserves limit (parallel to spokeLabels).
  /// @dev salt Root salt for deterministic CREATE2 deployment; orchestration derives per-batch salts.
  struct FullDeployInputs {
    address accessManagerAdmin;
    address hubAdmin;
    address hubConfiguratorAdmin;
    address treasurySpokeOwner;
    address spokeAdmin;
    address spokeProxyAdminOwner;
    address spokeConfiguratorAdmin;
    address gatewayOwner;
    address positionManagerOwner;
    address nativeWrapper;
    bool deployNativeTokenGateway;
    bool deploySignatureGateway;
    bool deployPositionManagers;
    bool grantRoles;
    string[] hubLabels;
    string[] spokeLabels;
    uint16[] spokeMaxReservesLimits;
    bytes32 salt;
  }

  /// @dev Periphery-only inputs for deploying gateways and position managers independently.
  /// @dev gatewayOwner The owner of the native token and signature gateways.
  /// @dev positionManagerOwner The owner of the position manager contracts (giver/taker/config).
  /// @dev nativeWrapper The address of the native wrapper (required when deployNativeTokenGateway is true).
  /// @dev deployNativeTokenGateway Whether to deploy the NativeTokenGateway.
  /// @dev deploySignatureGateway Whether to deploy the SignatureGateway.
  /// @dev deployPositionManagers Whether to deploy the position manager batch (giver/taker/config).
  struct PeripheryDeployInputs {
    address gatewayOwner;
    address positionManagerOwner;
    address nativeWrapper;
    bool deployNativeTokenGateway;
    bool deploySignatureGateway;
    bool deployPositionManagers;
  }

  /// @dev Extracts periphery inputs from full deploy inputs.
  function _extractPeripheryInputs(
    FullDeployInputs memory inputs
  ) internal pure returns (PeripheryDeployInputs memory) {
    return
      PeripheryDeployInputs({
        gatewayOwner: inputs.gatewayOwner,
        positionManagerOwner: inputs.positionManagerOwner,
        nativeWrapper: inputs.nativeWrapper,
        deployNativeTokenGateway: inputs.deployNativeTokenGateway,
        deploySignatureGateway: inputs.deploySignatureGateway,
        deployPositionManagers: inputs.deployPositionManagers
      });
  }

  function _validateUniqueLabels(string[] memory labels, string memory kind) internal pure {
    for (uint256 i; i < labels.length; i++) {
      for (uint256 j = i + 1; j < labels.length; j++) {
        require(
          keccak256(bytes(labels[i])) != keccak256(bytes(labels[j])),
          string.concat('duplicate ', kind, ' label: ', labels[i])
        );
      }
    }
  }
}
