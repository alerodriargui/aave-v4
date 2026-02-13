// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/Vm.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';

contract InputUtils {
  using ConfigReader for string;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  /// @notice Pre-computed salts for each deployment batch, derived from a single root salt.
  struct DerivedSalts {
    bytes32 rootSalt;
    bytes32 accessSalt;
    bytes32 configuratorSalt;
    bytes32[] hubSalts;
    bytes32[] spokeSalts;
    bytes32 gatewaySalt;
  }

  /// @dev accessManagerAdmin The default admin of the access manager.
  /// @dev hubAdmin The admin of the hub.
  /// @dev hubConfiguratorAdmin The admin granted all hub configurator roles.
  /// @dev treasurySpokeOwner The owner of the treasury spoke.
  /// @dev spokeAdmin The spoke admin.
  /// @dev spokeProxyAdminOwner The owner of the spoke proxyAdmin.
  /// @dev spokeConfiguratorAdmin The admin granted all spoke configurator roles.
  /// @dev gatewayOwner The owner of the native token and signature gateways.
  /// @dev nativeWrapper The address of the native wrapper.
  /// @dev grantRoles A boolean indicating if roles should be granted.
  /// @dev hubLabels An array of hub labels; the number of hub labels defines the number of hubs to deploy.
  /// @dev spokeLabels An array of spoke labels; the number of spoke labels defines the number of spokes to deploy.
  /// @dev spokeMaxReservesLimits Per-spoke max user reserves limit (parallel to spokeLabels).
  /// @dev spokeOracleDecimals Per-spoke oracle decimal precision (parallel to spokeLabels).
  /// @dev spokeOracleDescriptions Per-spoke oracle description, e.g. "PRIME_SPOKE (USD)" (parallel to spokeLabels).
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
    bool grantRoles;
    string[] hubLabels;
    string[] spokeLabels;
    uint16[] spokeMaxReservesLimits;
    uint8[] spokeOracleDecimals;
    string[] spokeOracleDescriptions;
    bytes32 salt;
  }

  /// @notice Builds FullDeployInputs from a ConfigReader-format JSON string.
  /// @param json The raw JSON string (ConfigReader format).
  /// @param infra The infrastructure config parsed from JSON.
  /// @param hubCount Number of hubs defined in the JSON.
  /// @param spokeCount Number of spokes defined in the JSON.
  /// @param grantRoles Whether the orchestration should grant roles immediately.
  function _buildDeployInputs(
    string memory json,
    ConfigReader.InfrastructureConfig memory infra,
    uint256 hubCount,
    uint256 spokeCount,
    bool grantRoles
  ) internal view returns (FullDeployInputs memory inputs) {
    string[] memory hubLabels = new string[](hubCount);
    for (uint256 i; i < hubCount; i++) {
      hubLabels[i] = json.hubKey(i);
    }

    string[] memory spokeLabels = new string[](spokeCount);
    uint16[] memory limits = new uint16[](spokeCount);
    uint8[] memory oracleDecimals = new uint8[](spokeCount);
    string[] memory oracleDescriptions = new string[](spokeCount);
    for (uint256 i; i < spokeCount; i++) {
      ConfigReader.SpokeDeployConfig memory cfg = json.readSpoke(i);
      spokeLabels[i] = cfg.key;
      limits[i] = cfg.maxUserReservesLimit;
      oracleDecimals[i] = cfg.oracleDecimals;
      oracleDescriptions[i] = string.concat(cfg.key, cfg.oracleSuffix);
    }

    inputs = FullDeployInputs({
      accessManagerAdmin: infra.accessManagerAdmin,
      hubAdmin: infra.hubConfiguratorAdmin,
      hubConfiguratorAdmin: infra.hubConfiguratorAdmin,
      treasurySpokeOwner: infra.treasurySpokeOwner,
      spokeAdmin: infra.spokeConfiguratorAdmin,
      spokeProxyAdminOwner: infra.spokeProxyAdminOwner,
      spokeConfiguratorAdmin: infra.spokeConfiguratorAdmin,
      gatewayOwner: infra.gatewayOwner,
      nativeWrapper: infra.nativeWrapper,
      grantRoles: grantRoles,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: limits,
      spokeOracleDecimals: oracleDecimals,
      spokeOracleDescriptions: oracleDescriptions,
      salt: keccak256(bytes(infra.salt))
    });
  }

  /// @notice Computes all derived salts from the deploy inputs, mirroring orchestration logic.
  ///         Use this to inspect deterministic addresses before deployment.
  function computeDerivedSalts(
    FullDeployInputs memory inputs
  ) internal pure returns (DerivedSalts memory salts) {
    bytes32 rootSalt = keccak256(abi.encode(inputs.salt));
    salts.rootSalt = rootSalt;
    salts.accessSalt = rootSalt;
    salts.configuratorSalt = keccak256(abi.encode(rootSalt, 'config'));

    salts.hubSalts = new bytes32[](inputs.hubLabels.length);
    for (uint256 i; i < inputs.hubLabels.length; i++) {
      salts.hubSalts[i] = keccak256(abi.encode(rootSalt, 'hub', inputs.hubLabels[i]));
    }

    salts.spokeSalts = new bytes32[](inputs.spokeLabels.length);
    for (uint256 i; i < inputs.spokeLabels.length; i++) {
      salts.spokeSalts[i] = keccak256(abi.encode(rootSalt, 'spoke', inputs.spokeLabels[i]));
    }

    salts.gatewaySalt = keccak256(abi.encode(rootSalt, 'gateways'));
  }

  function _etchCreate2Factory() internal virtual {
    vm.etch(
      Create2Utils.CREATE2_FACTORY,
      hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3'
    );
  }
}
