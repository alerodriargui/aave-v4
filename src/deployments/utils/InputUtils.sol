// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/StdToml.sol';
import 'forge-std/Vm.sol';

contract InputUtils {
  using stdToml for string;

  struct FullDeployInputs {
    address admin;
    address nativeWrapperAddress;
    bool setRoles;
    string[] hubLabels;
    string[] spokeLabels;
  }

  struct SpokeDeployInputs {
    address admin;
    bool setRoles;
    string spokeLabel;
  }

  struct HubDeployInputs {
    address admin;
    bool setRoles;
    string hubLabel;
  }

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  function loadFullDeployInputs(
    string memory inputPath
  ) public view returns (FullDeployInputs memory inputs) {
    string memory toml = vm.readFile(inputPath);
    inputs.admin = toml.readAddress('.admin');
    inputs.nativeWrapperAddress = toml.readAddress('.nativeWrapperAddress');
    inputs.setRoles = toml.readBool('.setRoles');
    inputs.hubLabels = toml.readStringArray('.hubLabels');
    inputs.spokeLabels = toml.readStringArray('.spokeLabels');
    return inputs;
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
