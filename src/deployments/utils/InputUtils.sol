// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';

contract InputUtils {
  using stdJson for string;

  /// @dev accessManagerAdmin The default admin of the access manager.
  /// @dev hubAdmin The admin of the hub.
  /// @dev hubConfiguratorOwner The admin of the hub configurator.
  /// @dev treasurySpokeOwner The owner of the treasury spoke.
  /// @dev spokeAdmin The spoke admin.
  /// @dev spokeProxyAdminOwner The owner of the spoke proxyAdmin.
  /// @dev spokeConfiguratorOwner The admin of the spoke configurator.
  /// @dev gatewayOwner The owner of the native token and signature gateways.
  /// @dev nativeWrapperAddress The address of the native wrapper.
  /// @dev grantRoles A boolean indicating if roles should be granted.
  /// @dev hubLabels An array of hub labels; the number of hub labels defines the number of hubs to deploy.
  /// @dev spokeLabels An array of spoke labels; the number of spoke labels defines the number of spokes to deploy.
  struct FullDeployInputs {
    address accessManagerAdmin;
    address hubAdmin;
    address hubConfiguratorOwner;
    address treasurySpokeOwner;
    address spokeAdmin;
    address spokeProxyAdminOwner;
    address spokeConfiguratorOwner;
    address gatewayOwner;
    address nativeWrapperAddress;
    bool grantRoles;
    string[] hubLabels;
    string[] spokeLabels;
  }

  struct SpokeDeployInputs {
    address admin;
    bool grantRoles;
    string spokeLabel;
  }

  struct HubDeployInputs {
    address admin;
    bool grantRoles;
    string hubLabel;
  }

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  function loadFullDeployInputs(
    string memory inputPath
  ) public view returns (FullDeployInputs memory inputs) {
    string memory json = vm.readFile(inputPath);
    inputs.accessManagerAdmin = json.readAddress('.accessManagerAdmin');
    inputs.hubAdmin = json.readAddress('.hubAdmin');
    inputs.hubConfiguratorOwner = json.readAddress('.hubConfiguratorOwner');
    inputs.treasurySpokeOwner = json.readAddress('.treasurySpokeOwner');
    inputs.spokeAdmin = json.readAddress('.spokeAdmin');
    inputs.spokeProxyAdminOwner = json.readAddress('.spokeProxyAdminOwner');
    inputs.spokeConfiguratorOwner = json.readAddress('.spokeConfiguratorOwner');
    inputs.nativeWrapperAddress = json.readAddress('.nativeWrapperAddress');
    inputs.grantRoles = json.readBool('.grantRoles');
    inputs.hubLabels = json.readStringArray('.hubLabels');
    inputs.spokeLabels = json.readStringArray('.spokeLabels');
  }

  function loadSpokeDeployInputs(
    string memory inputPath
  ) public view returns (SpokeDeployInputs memory) {
    string memory json = vm.readFile(inputPath);
    bytes memory data = vm.parseJson(json);
    SpokeDeployInputs memory inputs = abi.decode(data, (SpokeDeployInputs));
    return inputs;
  }

  function loadHubDeployInputs(
    string memory inputPath
  ) public view returns (HubDeployInputs memory) {
    string memory json = vm.readFile(inputPath);
    bytes memory data = vm.parseJson(json);
    HubDeployInputs memory inputs = abi.decode(data, (HubDeployInputs));
    return inputs;
  }
}
