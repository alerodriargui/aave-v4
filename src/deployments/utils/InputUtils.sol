// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

contract InputUtils {
  /// @dev accessManagerAdmin The default admin of the access manager.
  /// @dev hubAdmin The admin of the hub.
  /// @dev hubConfiguratorAdmin The admin granted all hub configurator roles.
  /// @dev treasurySpokeOwner The owner of the treasury spoke.
  /// @dev spokeAdmin The spoke admin.
  /// @dev spokeProxyAdminOwner The owner of the spoke proxyAdmin.
  /// @dev spokeConfiguratorAdmin The admin granted all spoke configurator roles.
  /// @dev gatewayOwner The owner of the native token and signature gateways.
  /// @dev nativeWrapper The address of the native wrapper (required when deployNativeTokenGateway is true).
  /// @dev deployNativeTokenGateway Whether to deploy the NativeTokenGateway (from periphery config).
  /// @dev deploySignatureGateway Whether to deploy the SignatureGateway (from periphery config).
  /// @dev grantRoles A boolean indicating if roles should be granted.
  /// @dev hubLabels An array of hub labels; the number of hub labels defines the number of hubs to deploy.
  /// @dev spokeLabels An array of spoke labels; the number of spoke labels defines the number of spokes to deploy.
  /// @dev spokeMaxReservesLimits Per-spoke max user reserves limit (parallel to spokeLabels).
  /// @dev spokeOracleDecimals Per-spoke oracle decimal precision (parallel to spokeLabels).
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
    address nativeWrapper;
    bool deployNativeTokenGateway;
    bool deploySignatureGateway;
    bool grantRoles;
    string[] hubLabels;
    string[] spokeLabels;
    uint16[] spokeMaxReservesLimits;
    uint8[] spokeOracleDecimals;
    bytes32 salt;
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
