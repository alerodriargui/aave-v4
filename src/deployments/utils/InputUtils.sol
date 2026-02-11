// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';
import {Create2Utils} from 'src/deployments/utils/libraries/Create2Utils.sol';

contract InputUtils {
  using stdJson for string;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

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
  /// @dev salt The root salt to use for the deployment.
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
    bytes32 salt;
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

  function loadFullDeployInputs(
    string memory inputPath
  ) public view returns (FullDeployInputs memory inputs) {
    string memory json = vm.readFile(inputPath);
    inputs.accessManagerAdmin = json.readAddress('.accessManagerAdmin');
    inputs.hubAdmin = json.readAddress('.hubAdmin');
    inputs.hubConfiguratorAdmin = json.readAddress('.hubConfiguratorAdmin');
    inputs.treasurySpokeOwner = json.readAddress('.treasurySpokeOwner');
    inputs.spokeAdmin = json.readAddress('.spokeAdmin');
    inputs.spokeProxyAdminOwner = json.readAddress('.spokeProxyAdminOwner');
    inputs.spokeConfiguratorAdmin = json.readAddress('.spokeConfiguratorAdmin');
    inputs.gatewayOwner = json.readAddress('.gatewayOwner');
    inputs.nativeWrapper = json.readAddress('.nativeWrapper');
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

  function _etchCreate2Factory() internal virtual {
    vm.etch(
      Create2Utils.CREATE2_FACTORY,
      hex'7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3'
    );
  }
}
