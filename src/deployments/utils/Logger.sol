// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';
import {console2 as console} from 'forge-std/console2.sol';

contract Logger {
  using stdJson for string;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));
  struct AddressEntry {
    string label;
    address value;
  }

  struct ValueEntry {
    string label;
    uint256 value;
  }

  string internal _outputPath;
  string internal _root;
  string internal _json;

  constructor(string memory outputPath_) {
    _root = 'root';
    _outputPath = outputPath_;
    _json = _root;
  }

  function log(string memory label, address value) public pure {
    _log(label, value);
  }

  function log(string memory label, uint256 value) public pure {
    _log(label, value);
  }

  function log(string memory value) public pure {
    _log(value);
  }

  function write(string memory label, address value) public {
    _write(label, value);
  }

  function write(string memory label, uint256 value) public {
    _write(label, value);
  }

  function write(string memory value) public {
    _write(value);
  }

  function writeGroup(string memory groupLabel, AddressEntry[] memory entries) public {
    _writeGroup(groupLabel, entries);
  }

  function writeGroup(string memory groupLabel, ValueEntry[] memory entries) public {
    _writeGroup(groupLabel, entries);
  }

  function save(string memory fileName, bool withTimestamp) public {
    console.log();
    console.log('Saving log to %s', _outputPath);
    string memory appendedMetadata = withTimestamp ? string.concat(getTimestamp(), '-') : '';
    vm.writeJson(_json, string.concat(_outputPath, appendedMetadata, fileName));
  }

  function _log(string memory label, address value) internal pure {
    console.log('%s: %s', label, value);
  }

  function _log(string memory label, uint256 value) internal pure {
    console.log('%s: %s', label, value);
  }

  function _log(string memory value) internal pure {
    console.log(value);
  }

  function _write(string memory label, address value) internal {
    _json = vm.serializeAddress(_root, label, value);
  }

  function _write(string memory label, uint256 value) internal {
    _json = vm.serializeString(_root, label, vm.toString(value));
  }

  function _write(string memory value) internal {
    _json = vm.serializeString(_root, 'message', value);
  }

  function _writeGroup(string memory groupLabel, AddressEntry[] memory entries) internal {
    string memory group;
    for (uint256 i = 0; i < entries.length; i++) {
      group = vm.serializeAddress(groupLabel, entries[i].label, entries[i].value);
    }
    _json = vm.serializeString(_root, groupLabel, group);
  }

  function _writeGroup(string memory groupLabel, ValueEntry[] memory entries) internal {
    string memory group;
    for (uint256 i = 0; i < entries.length; i++) {
      group = vm.serializeString(groupLabel, entries[i].label, vm.toString(entries[i].value));
    }
    _json = vm.serializeString(_root, groupLabel, group);
  }

  function getTimestamp() public returns (string memory result) {
    string[] memory command = new string[](3);

    command[0] = 'bash';
    command[1] = '-c';
    command[2] = 'response="$(date +%s)"; cast abi-encode "response(string)" $response;';
    bytes memory timestamp = vm.ffi(command);
    (result) = abi.decode(timestamp, (string));

    return result;
  }
}
